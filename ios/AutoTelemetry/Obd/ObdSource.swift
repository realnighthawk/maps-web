import Foundation

struct ObdFrame {
    var speedKmh: Double?
    var readings: [String: Reading]
}

/// Where readings come from: a real adapter or the demo simulator.
protocol ObdSource: AnyObject {
    /// Opens the link and prepares the adapter. Throws a message fit to show the user.
    func connect() async throws
    /// The VIN the car reports, if it does.
    func readVin() async -> String?
    /// Tells the source which car it is reading, once known, so it can add that car's own readings.
    func configure(vehicle: Vehicle?)
    /// One poll cycle.
    func poll() async -> ObdFrame
    func close()
}

extension ObdSource {
    func configure(vehicle: Vehicle?) {}
}

struct ObdError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Drives an ELM327 adapter (over any text transport): setup, protocol, which modules report which PIDs, polling.
///
/// It reads everything the car reports. The standard PIDs come from asking each module what it supports; a car family
/// may add readings of its own (see VehicleProfile), chosen from the VIN. Nothing is guessed: a request the car
/// doesn't answer is dropped at connect time.
final class ElmSource: ObdSource {
    private let link: ElmLink
    private let protocolOrder: [String]
    private var profile: VehicleProfile?
    private var specs: [PidSpec] = []
    /// PID -> request address of the module that reports it ("" when the car's protocol has no addressing).
    private var route: [String: String] = [:]
    private var extended: [ExtendedPid] = []
    private var currentModule = ""
    private var cycle = 0
    private var didProbe = false

    /// [hint] is the garage car this drive is for. It only orders the protocol fallback and picks the profile to try;
    /// the VIN the car reports later (see configure) is what decides which car it really is.
    init(link: ElmLink, hint: Vehicle? = nil) {
        self.link = link
        protocolOrder = ElmProtocol.order(forYear: hint?.year)
        profile = CarProfiles.match(hint)
    }

    func configure(vehicle: Vehicle?) { profile = CarProfiles.match(vehicle) }

    func connect() async throws {
        Diag.verbose = true
        try await link.open()
        Diag.log("link open")

        var version = ""
        for cmd in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] {
            let r = try? await link.send(cmd, timeout: cmd == "ATZ" ? 5 : 3)
            if cmd == "ATZ" { version = r ?? "" }
        }
        // ATZ prints the adapter's name ("ELM327 v1.5"). Nothing at all means the radio link is up but the
        // adapter's data line isn't answering.
        guard !version.isEmpty else {
            throw ObdError(message: "Connected to the adapter, but it isn't answering. Unplug it, plug it back in, and try again.")
        }

        let probe = await ElmProtocol.establish(link: link, order: protocolOrder)
        if ElmProtocol.failed(probe) {
            let name = version.split(separator: "\n").last.map(String.init) ?? "ELM327"
            throw ObdError(message: "Connected to the adapter (\(name)), but the car didn't answer on any protocol. Check the adapter is pushed in fully and turn the car on (dash lit; for a combustion car the engine can stay off), then try again.")
        }
    }

    func readVin() async -> String? { ObdParser.vin((try? await link.send("0902", timeout: 5)) ?? "") }

    func poll() async -> ObdFrame {
        if !didProbe { await probe() }
        cycle += 1
        var readings: [String: Reading] = [:]

        // Standard PIDs, grouped by the module that reports them so the address changes as rarely as possible.
        let due = specs.filter { PidPlan.isDue($0.tier, cycle: cycle) }
        let byModule = Dictionary(grouping: due) { route[$0.pid] ?? "" }
        for module in byModule.keys.sorted() {
            await address(module)
            for spec in byModule[module] ?? [] {
                guard let raw = try? await link.send(spec.command, timeout: 2) else { continue }
                if let v = spec.decode(ObdParser.dataBytes(raw)) { readings[spec.pid] = Reading(label: spec.label, value: v, unit: spec.unit) }
            }
        }

        // The car family's own readings.
        let dueExtended = extended.filter { PidPlan.isDue($0.tier, cycle: cycle) }
        for module in Set(dueExtended.map(\.module)).sorted() {
            await address(module)
            for x in dueExtended where x.module == module {
                guard let raw = try? await link.send("22" + x.did, timeout: 2),
                      let data = ObdParser.udsData(raw, did: x.did), let v = x.decode(data) else { continue }
                readings[x.key] = Reading(label: x.label, value: v, unit: x.unit)
            }
        }

        if Diag.verbose {
            Diag.log("first poll: " + readings.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.value.map { String(format: "%.1f", $0) } ?? "-")" }.joined(separator: " "))
            Diag.verbose = false
        }
        return ObdFrame(speedKmh: readings["0D"]?.value, readings: readings)
    }

    /// Sends requests to one module only (so replies never mix); "" leaves the adapter's default (all modules).
    private func address(_ module: String) async {
        guard !module.isEmpty, module != currentModule else { return }
        _ = try? await link.send("ATSH \(module)", timeout: 2)
        currentModule = module
    }

    /// Asks every module what it supports (headers on, so each reply names its module), plans which module answers
    /// which PID, and checks the car family's own readings against the car.
    private func probe() async {
        didProbe = true
        _ = try? await link.send("ATH1", timeout: 3)
        var perModule: [String: Set<String>] = [:]
        for base in [0x00, 0x20, 0x40, 0x60, 0x80, 0xA0] {
            guard let raw = try? await link.send(String(format: "01%02X", base), timeout: 3) else { break }
            let replies = ElmProtocol.canReplies(raw).filter { $0.data.count >= 6 && $0.data[0] == 0x41 }
            if replies.isEmpty { break }
            var more = false
            for r in replies {
                guard let module = ElmProtocol.requestAddress(forResponse: r.module) else { continue }
                let bytes = Array(r.data[2..<6])
                perModule[module, default: []].formUnion(ObdParser.supported(base: base, bytes: bytes))
                if bytes[3] & 1 == 1 { more = true }
            }
            if !more { break }
        }
        _ = try? await link.send("ATH0", timeout: 3)
        currentModule = ""

        if perModule.isEmpty {
            await probeUnaddressed()
        } else {
            route = PidPlan.route(perModule: perModule)
            specs = PidRegistry.all.filter { route[$0.pid] != nil }
            Diag.log("modules \(perModule.keys.sorted().map { "\($0): \(perModule[$0]!.count) PIDs" }.joined(separator: ", ")); reading \(specs.map(\.pid).joined(separator: " "))")
        }

        // The car family's own readings: keep only the ones this car answers.
        if let profile {
            for x in profile.pids {
                await address(x.module)
                if let raw = try? await link.send("22" + x.did, timeout: 2), ObdParser.udsData(raw, did: x.did) != nil { extended.append(x) }
            }
            Diag.log("profile \(profile.name): \(extended.count) of \(profile.pids.count) readings answered")
        }
    }

    /// Older cars (no CAN addressing): one module answers, replies carry no module id.
    private func probeUnaddressed() async {
        var supported = Set<String>()
        for base in [0x00, 0x20, 0x40, 0x60, 0x80, 0xA0] {
            guard let raw = try? await link.send(String(format: "01%02X", base), timeout: 3) else { continue }
            let bytes = ObdParser.dataBytes(raw)
            guard bytes.count >= 4 else { break }
            supported.formUnion(ObdParser.supported(base: base, bytes: bytes))
            if bytes[3] & 1 == 0 { break }
        }
        specs = supported.isEmpty ? PidRegistry.all.filter { $0.tier == .fast } : PidRegistry.all.filter { supported.contains($0.pid) }
        Diag.log("car reports \(supported.count) PIDs; reading \(specs.map(\.pid).joined(separator: " "))")
    }

    func close() { link.close() }
}

/// A line-oriented ELM327 link: send a command, get the text up to the ">" prompt.
protocol ElmLink: AnyObject {
    func open() async throws
    func send(_ command: String, timeout: TimeInterval) async throws -> String
    func close()
}
