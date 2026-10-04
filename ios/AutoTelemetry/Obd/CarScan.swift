import Foundation

/// Finds out what a car actually answers, so a vehicle profile can be written from evidence instead of guesses.
///
/// Read-only: it only sends "tell me" requests (Mode 01 and UDS ReadDataByIdentifier, service 22) and records the raw
/// replies in the connection log. It never writes, never starts a diagnostic session, never changes anything.
///
/// What it learns:
///   1. The adapter, protocol and 12 V reading, and which modules answer the standard Mode 01 request.
///   2. The standard PIDs the car lists as supported, and its VIN.
///   3. For each possible engine/battery module address (7E0 to 7E7): whether it answers service 22, and whether it
///      answers the community-reported Mach-E battery requests (22 4801 charge, 22 480B HV current). A module that
///      does gets a short sweep of nearby identifiers, repeated reads, so changing values can be told from constants.
///
/// Compare the log against the dashboard (note the charge percentage while it runs) to work out each scale.
enum CarScan {
    /// Community-reported Ford EV battery identifiers. Unverified: this scan is how they get verified (or not).
    static let batteryCandidates = ["4801", "480B"]
    static let sweep = (0x4800...0x481F).map { String(format: "%04X", $0) }
    static let modules = (0x7E0...0x7E7).map { String(format: "%X", $0) }

    static func run(link: ElmLink, car: Vehicle, progress: @MainActor @escaping (String) -> Void) async {
        Diag.verbose = true
        Diag.log("=== CAR SCAN: \(car.displayName), VIN \(car.vin.isEmpty ? "unknown" : car.vin), \(car.drivetrain) ===")
        Diag.log("Note the dashboard charge % now: ____")

        func send(_ cmd: String, _ timeout: TimeInterval = 4) async -> String { (try? await link.send(cmd, timeout: timeout)) ?? "" }
        func positive(_ reply: String) -> Bool { reply.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "").contains("6248") }

        await progress("Connecting to the adapter…")
        do { try await link.open() } catch {
            Diag.log("scan: couldn't open the adapter: \(error.localizedDescription)")
            await progress("Couldn't connect to the adapter.")
            return
        }
        defer { link.close() }

        // Headers on, so every reply says which module sent it.
        for c in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH1", "ATSP0"] { _ = await send(c, c == "ATZ" ? 5 : 3) }
        await progress("Reading the adapter and protocol…")
        _ = await send("ATDP"); _ = await send("ATRV")

        await progress("Finding which modules answer…")
        // Functional request: every OBD module answers, each with its own id (headers are on).
        let probe = await ElmProtocol.establish(link: link, order: ElmProtocol.order(forYear: car.year))
        if ElmProtocol.failed(probe) {
            Diag.log("scan: the car didn't answer on any protocol. Turn it on (Ready) and run the scan again.")
            await progress("The car didn't answer. Turn it on and try again.")
            return
        }

        await progress("Reading the standard PID list…")
        for pid in ["0120", "0140", "0160", "0180", "01A0"] { _ = await send(pid) }
        _ = await send("0902", 6)

        for (i, m) in modules.enumerated() {
            await progress("Checking module 7E\(m.dropFirst(2)) (\(i + 1) of \(modules.count))…")
            _ = await send("ATSH \(m)")
            _ = await send("22F190", 4)                       // does this module speak service 22 at all?
            let first = await send("22" + batteryCandidates[0], 4)
            guard positive(first) else { continue }

            Diag.log("--- module \(m) answers 22 4801; sweeping 4800-481F, then repeating the battery reads ---")
            for did in sweep { _ = await send("22" + did, 3) }
            for round in 1...3 {
                Diag.log("--- repeat \(round) ---")
                for did in batteryCandidates { _ = await send("22" + did, 3) }
                try? await Task.sleep(for: .seconds(1))
            }
        }

        _ = await send("ATSH 7DF"); _ = await send("ATH0")
        Diag.log("=== SCAN DONE ===")
        await progress("Scan finished.")
    }
}
