import CoreBluetooth
import Foundation
import Observation

struct FoundAdapter: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
}

/// Finds and connects to Bluetooth Low Energy ELM327 adapters. iOS gives apps no access to classic-Bluetooth (SPP)
/// serial adapters without Apple's MFi program, so only BLE adapters (Veepeak BLE+, vLinker BLE, OBDLink CX...) work.
@MainActor @Observable
final class BleAdapters: NSObject, CBCentralManagerDelegate {
    private(set) var state: CBManagerState = .unknown
    private(set) var found: [FoundAdapter] = []
    private(set) var scanning = false

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var peripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var links: [UUID: BleLink] = [:]
    @ObservationIgnored private var wantsScan = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        wantsScan = true
        guard central.state == .poweredOn else { return }
        found = []
        scanning = true
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        wantsScan = false
        scanning = false
        if central.isScanning { central.stopScan() }
    }

    /// The link for a device found by scanning (or remembered from before). One link per adapter, reused: a second
    /// link object on the same peripheral would take over its delegate and steal the first one's replies.
    func link(for id: UUID) -> BleLink? {
        if let existing = links[id] { return existing }
        guard let p = peripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else { return nil }
        peripherals[id] = p
        let l = BleLink(central: central, peripheral: p)
        links[id] = l
        return l
    }

    // MARK: CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            state = central.state
            Diag.log("bluetooth state \(central.state.rawValue)")
            if central.state == .poweredOn, wantsScan { startScan() }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            // Nameless devices are almost always beacons and headphones, not adapters.
            guard let name, !name.isEmpty else { return }
            peripherals[peripheral.identifier] = peripheral
            let item = FoundAdapter(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
            if let i = found.firstIndex(where: { $0.id == item.id }) { found[i] = item } else { found.append(item) }
            found.sort { $0.rssi > $1.rssi }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated { links[peripheral.identifier]?.didConnect() }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { links[peripheral.identifier]?.didFail(error) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { links[peripheral.identifier]?.didDisconnect() }
    }
}

/// One connected adapter as an ELM327 text link.
@MainActor
final class BleLink: NSObject, ElmLink, CBPeripheralDelegate {
    private let central: CBCentralManager
    private let peripheral: CBPeripheral
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?

    private var onReady: CheckedContinuation<Void, Error>?
    private var onReply: CheckedContinuation<String, Error>?
    private var buffer = ""
    private var pendingServices = 0
    private var discovered: [CBService] = []

    init(central: CBCentralManager, peripheral: CBPeripheral) {
        self.central = central; self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    private var serial = 0

    func open() async throws {
        let message = "Couldn't connect to the adapter. Make sure it's plugged in and nothing else is connected to it."
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            onReady = c
            serial += 1
            let mine = serial
            central.connect(peripheral)
            Task {
                try? await Task.sleep(for: .seconds(10))
                if serial == mine { finishOpen(.failure(ObdError(message: message))) }
            }
        }
    }

    func send(_ command: String, timeout: TimeInterval) async throws -> String {
        guard let write = writeChar else { throw ObdError(message: "The adapter isn't connected.") }
        buffer = ""
        // Write-without-response is dropped silently when the radio isn't ready; use a confirmed write if it offers one.
        let noRsp = write.properties.contains(.writeWithoutResponse)
        let type: CBCharacteristicWriteType =
            noRsp && (peripheral.canSendWriteWithoutResponse || !write.properties.contains(.write)) ? .withoutResponse : .withResponse
        if Diag.verbose { Diag.log("tx \(command)") }
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            onReply = c
            serial += 1
            let mine = serial
            peripheral.writeValue(Data((command + "\r").utf8), for: write, type: type)
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                // Still waiting on this very command: give up on it.
                if serial == mine, let r = onReply {
                    onReply = nil
                    r.resume(throwing: ObdError(message: "The adapter didn't answer."))
                }
            }
        }
    }

    func close() {
        onReply?.resume(throwing: ObdError(message: "Disconnected.")); onReply = nil
        onReady?.resume(throwing: ObdError(message: "Disconnected.")); onReady = nil
        if peripheral.state != .disconnected { central.cancelPeripheralConnection(peripheral) }
    }

    // MARK: connection events (forwarded by BleAdapters)

    func didConnect() { peripheral.discoverServices(nil) }
    func didFail(_ error: Error?) { finishOpen(.failure(ObdError(message: "Couldn't connect to the adapter."))) }
    func didDisconnect() {
        writeChar = nil; notifyChar = nil
        onReply?.resume(throwing: ObdError(message: "The adapter disconnected.")); onReply = nil
        finishOpen(.failure(ObdError(message: "The adapter disconnected.")))
    }

    private func finishOpen(_ r: Result<Void, Error>) {
        guard let c = onReady else { return }
        onReady = nil
        c.resume(with: r)
    }

    // MARK: CBPeripheralDelegate

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            let services = peripheral.services ?? []
            pendingServices = services.count
            discovered = []
            Diag.log("connected; services: " + services.map(\.uuid.uuidString).joined(separator: " "))
            if services.isEmpty { finishOpen(.failure(ObdError(message: "This device doesn't look like an OBD adapter."))) }
            services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            pendingServices -= 1
            discovered.append(service)
            Diag.log("service \(service.uuid.uuidString): " + (service.characteristics ?? []).map { "\($0.uuid.uuidString)[\(Self.describe($0.properties))]" }.joined(separator: " "))
            guard pendingServices <= 0 else { return }

            // Serial adapters expose one write and one notify characteristic, in the same service. Prefer the
            // known ELM327 BLE layouts (FFF0: FFF1/FFF2, FFE0: FFE1, 18F0: 2AF0/2AF1), then any service that has both.
            func canNotify(_ c: CBCharacteristic) -> Bool { c.properties.contains(.notify) || c.properties.contains(.indicate) }
            func canWrite(_ c: CBCharacteristic) -> Bool { c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) }
            let preferred = ["FFF0", "FFE0", "18F0"]
            let candidates = discovered.filter { svc in
                let cs = svc.characteristics ?? []
                return cs.contains(where: canNotify) && cs.contains(where: canWrite)
            }.sorted { a, b in (preferred.firstIndex(of: a.uuid.uuidString) ?? 99) < (preferred.firstIndex(of: b.uuid.uuidString) ?? 99) }

            guard let svc = candidates.first else {
                Diag.log("no service with both a write and a notify characteristic")
                return finishOpen(.failure(ObdError(message: "Connected, but this device doesn't look like an OBD adapter.")))
            }
            let cs = svc.characteristics ?? []
            let known = ["FFF1", "FFF2", "FFE1", "2AF0", "2AF1"]
            notifyChar = cs.filter(canNotify).first { known.contains($0.uuid.uuidString) } ?? cs.first(where: canNotify)
            writeChar = cs.filter(canWrite).first { known.contains($0.uuid.uuidString) } ?? cs.first(where: canWrite)
            Diag.log("using service \(svc.uuid.uuidString), notify \(notifyChar?.uuid.uuidString ?? "-"), write \(writeChar?.uuid.uuidString ?? "-")")
            peripheral.setNotifyValue(true, for: notifyChar!)
        }
    }

    private static func describe(_ p: CBCharacteristicProperties) -> String {
        var parts: [String] = []
        if p.contains(.read) { parts.append("read") }
        if p.contains(.write) { parts.append("write") }
        if p.contains(.writeWithoutResponse) { parts.append("writeNoRsp") }
        if p.contains(.notify) { parts.append("notify") }
        if p.contains(.indicate) { parts.append("indicate") }
        return parts.joined(separator: ",")
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            if error == nil, c.isNotifying { finishOpen(.success(())) }
            else { finishOpen(.failure(ObdError(message: "Couldn't start listening to the adapter."))) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            guard let d = c.value else { return }
            buffer += String(decoding: d, as: UTF8.self)
            // The adapter ends every answer with the ">" prompt.
            guard buffer.contains(">"), let reply = onReply else { return }
            onReply = nil
            let text = buffer.replacingOccurrences(of: ">", with: "").replacingOccurrences(of: "SEARCHING...", with: "")
                .replacingOccurrences(of: "\r", with: "\n")
                .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                .joined(separator: "\n")
            if Diag.verbose { Diag.log("rx \(text.replacingOccurrences(of: "\n", with: " | "))") }
            reply.resume(returning: text)
        }
    }
}

