import Foundation

/// How often a reading is polled. Over Bluetooth each request takes about a tenth of a second, so a long PID list
/// can't all run every second: what changes fast is read every cycle, the rest less often.
enum Tier { case fast, normal, slow }

/// How to request one OBD-II PID and decode its data bytes (SAE J1979 formulas).
struct PidSpec {
    let command: String
    let label: String
    let unit: String
    var tier: Tier = .normal
    let decode: ([Int]) -> Double?
    /// "010C" -> "0C"
    var pid: String { String(command.dropFirst(2)) }
}

/// Every standard Mode 01 PID with a numeric value. Which of them a car supports is asked of the car, not guessed.
enum PidRegistry {
    private static func byte(_ b: [Int]) -> Double? { b.first.map(Double.init) }
    private static func pct(_ b: [Int]) -> Double? { b.first.map { Double($0) * 100 / 255 } }
    private static func temp(_ b: [Int]) -> Double? { b.first.map { Double($0 - 40) } }
    private static func trim(_ b: [Int]) -> Double? { b.first.map { (Double($0) - 128) * 100 / 128 } }
    private static func u16(_ b: [Int]) -> Double? { b.count >= 2 ? Double(b[0] * 256 + b[1]) : nil }
    private static func u16(_ scale: Double, _ offset: Double = 0) -> ([Int]) -> Double? { { u16($0).map { $0 * scale + offset } } }
    private static func p(_ cmd: String, _ label: String, _ unit: String, _ tier: Tier = .normal, _ decode: @escaping ([Int]) -> Double?) -> PidSpec {
        PidSpec(command: cmd, label: label, unit: unit, tier: tier, decode: decode)
    }

    static let all: [PidSpec] = [
        p("0104", "Calculated Engine Load", "%", .fast, pct),
        p("0105", "Engine Coolant Temperature", "°C", .normal, temp),
        p("0106", "Short Term Fuel Trim B1", "%", .normal, trim),
        p("0107", "Long Term Fuel Trim B1", "%", .normal, trim),
        p("0108", "Short Term Fuel Trim B2", "%", .normal, trim),
        p("0109", "Long Term Fuel Trim B2", "%", .normal, trim),
        p("010A", "Fuel Pressure", "kPa", .normal) { b in b.first.map { Double($0) * 3 } },
        p("010B", "Intake Manifold Pressure", "kPa", .normal, byte),
        p("010C", "Engine RPM", "rpm", .fast, u16(0.25)),
        p("010D", "Vehicle Speed", "km/h", .fast, byte),
        p("010E", "Timing Advance", "°", .normal) { b in b.first.map { Double($0) / 2 - 64 } },
        p("010F", "Intake Air Temperature", "°C", .normal, temp),
        p("0110", "MAF Air Flow Rate", "g/s", .normal, u16(0.01)),
        p("0111", "Throttle Position", "%", .fast, pct),
        p("011F", "Run Time Since Engine Start", "s", .slow, u16(1)),
        p("0121", "Distance With MIL On", "km", .slow, u16(1)),
        p("0122", "Fuel Rail Pressure (rel. manifold)", "kPa", .normal, u16(0.079)),
        p("0123", "Fuel Rail Gauge Pressure", "kPa", .normal, u16(10)),
        p("012C", "Commanded EGR", "%", .normal, pct),
        p("012D", "EGR Error", "%", .normal, trim),
        p("012E", "Commanded Evaporative Purge", "%", .normal, pct),
        p("012F", "Fuel Tank Level", "%", .normal, pct),
        p("0130", "Warm-ups Since Codes Cleared", "count", .slow, byte),
        p("0131", "Distance Since Codes Cleared", "km", .slow, u16(1)),
        p("0133", "Barometric Pressure", "kPa", .slow, byte),
        p("013C", "Catalyst Temperature B1S1", "°C", .normal, u16(0.1, -40)),
        p("013D", "Catalyst Temperature B2S1", "°C", .normal, u16(0.1, -40)),
        p("013E", "Catalyst Temperature B1S2", "°C", .normal, u16(0.1, -40)),
        p("013F", "Catalyst Temperature B2S2", "°C", .normal, u16(0.1, -40)),
        p("0142", "Control Module Voltage", "V", .normal, u16(0.001)),
        p("0143", "Absolute Load Value", "%", .normal, u16(100.0 / 255)),
        p("0144", "Commanded Equivalence Ratio", "λ", .normal, u16(1.0 / 32768)),
        p("0145", "Relative Throttle Position", "%", .fast, pct),
        p("0146", "Ambient Air Temperature", "°C", .normal, temp),
        p("0147", "Absolute Throttle Position B", "%", .fast, pct),
        p("0148", "Absolute Throttle Position C", "%", .fast, pct),
        p("0149", "Accelerator Pedal Position D", "%", .fast, pct),
        p("014A", "Accelerator Pedal Position E", "%", .fast, pct),
        p("014B", "Accelerator Pedal Position F", "%", .fast, pct),
        p("014C", "Commanded Throttle Actuator", "%", .normal, pct),
        p("014D", "Time Run With MIL On", "min", .slow, u16(1)),
        p("014E", "Time Since Codes Cleared", "min", .slow, u16(1)),
        p("0151", "Fuel Type", "code", .slow, byte),
        p("0152", "Ethanol Fuel Percentage", "%", .slow, pct),
        p("015A", "Relative Accelerator Pedal Position", "%", .fast, pct),
        p("015B", "Hybrid Battery Remaining Life", "%", .fast, pct),
        p("015C", "Engine Oil Temperature", "°C", .normal, temp),
        p("015D", "Fuel Injection Timing", "°", .normal, u16(1.0 / 128, -210)),
        p("015E", "Engine Fuel Rate", "L/h", .normal, u16(0.05)),
        p("0161", "Driver's Demand Engine Torque", "%", .fast) { b in b.first.map { Double($0) - 125 } },
        p("0162", "Actual Engine Torque", "%", .fast) { b in b.first.map { Double($0) - 125 } },
        p("0163", "Engine Reference Torque", "Nm", .slow, u16(1)),
    ]

    /// Throttle from whichever of the throttle and pedal PIDs this car reports.
    static func throttle(_ readings: [String: Reading]) -> Double? {
        for pid in ["11", "45", "49", "4A", "5A"] { if let v = readings[pid]?.value { return v } }
        return nil
    }
}

/// Parses ELM327 text responses.
enum ObdParser {
    /// Every hex byte in a reply, across lines ("0:" / "1:" multi-frame prefixes dropped).
    private static func bytes(_ response: String) -> [Int] {
        if response.isEmpty || response.localizedCaseInsensitiveContains("NO DATA") { return [] }
        var tokens: [String] = []
        for raw in response.split(whereSeparator: \.isNewline) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if let i = line.firstIndex(of: ":"), line.distance(from: line.startIndex, to: i) < 3 {
                line = String(line[line.index(after: i)...]).trimmingCharacters(in: .whitespaces)
            }
            if line.contains(" ") { tokens += line.split(separator: " ").map(String.init) }
            else { tokens += stride(from: 0, to: line.count - 1, by: 2).map { String(Array(line)[$0...$0 + 1]) } }
        }
        return tokens.compactMap { Int($0, radix: 16) }
    }

    /// Hex data bytes after the mode/PID echo ("41 0C 1A F8" -> [0x1A, 0xF8]). Empty on NO DATA or noise.
    static func dataBytes(_ response: String) -> [Int] {
        let b = bytes(response)
        return b.count > 2 ? Array(b.dropFirst(2)) : []
    }

    /// The data of a service 22 reply for [did] ("62 48 01 44 86" -> [0x44, 0x86]); nil for a refusal or another reply.
    static func udsData(_ response: String, did: String) -> [Int]? {
        let b = bytes(response)
        guard did.count == 4, let hi = Int(did.prefix(2), radix: 16), let lo = Int(did.suffix(2), radix: 16),
              b.count >= 3, b[0] == 0x62, b[1] == hi, b[2] == lo else { return nil }
        return Array(b.dropFirst(3))
    }

    /// Service 09 PID 02. Handles single-line and multi-line ISO 15765-4 responses.
    static func vin(_ response: String) -> String? {
        if response.isEmpty || response.localizedCaseInsensitiveContains("NO DATA") { return nil }
        let hex = response.split(whereSeparator: \.isNewline).map { raw -> String in
            var line = raw.trimmingCharacters(in: .whitespaces)
            if let i = line.firstIndex(of: ":"), line.distance(from: line.startIndex, to: i) < 3 {
                line = String(line[line.index(after: i)...])
            }
            return line.replacingOccurrences(of: " ", with: "")
        }.joined()
        let chars = Array(hex)
        // Frames read "49 02 01 <17 ASCII bytes>"; fall back to a bare 17-byte run.
        var start: Int?
        if let r = hex.range(of: "4902") { start = hex.distance(from: hex.startIndex, to: r.upperBound) + 2 }
        else if chars.count >= 34 { start = 0 }
        guard let s = start, chars.count >= s + 34 else { return nil }
        let vin = stride(from: s, to: s + 34, by: 2).compactMap { UInt8(String(chars[$0...$0 + 1]), radix: 16) }
            .map { Character(UnicodeScalar($0)) }
        let text = String(vin).trimmingCharacters(in: .whitespaces)
        return text.count == 17 && text.allSatisfy({ $0.isLetter || $0.isNumber }) ? text : nil
    }

    /// Mode 01 availability bitmaps (0100, 0120, ...) -> set of supported PIDs as 2-char hex.
    static func supported(base: Int, bytes: [Int]) -> Set<String> {
        guard bytes.count >= 4 else { return [] }
        let mask = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        return Set((0..<32).filter { (mask >> UInt32(31 - $0)) & 1 == 1 }.map { String(format: "%02X", base + $0 + 1) })
    }
}

/// Several modules answer Mode 01 on a modern car (the Mach-E has four), each with its own PID list. Each PID is
/// asked of one module that supports it, so replies never mix and nothing is asked of a module that lacks it.
enum PidPlan {
    /// [perModule] maps a module's request address (7E0...) to the PIDs it supports. The lowest address wins a tie.
    static func route(perModule: [String: Set<String>]) -> [String: String] {
        var route: [String: String] = [:]
        for module in perModule.keys.sorted() {
            for pid in perModule[module]! where route[pid] == nil { route[pid] = module }
        }
        return route
    }

    /// True if a reading of this tier is polled on cycle [cycle] (counted from 1). The first cycle reads everything.
    static func isDue(_ tier: Tier, cycle: Int) -> Bool {
        switch tier {
        case .fast: true
        case .normal: cycle == 1 || cycle % 5 == 0
        case .slow: cycle == 1 || cycle % 30 == 0
        }
    }
}
