import Foundation

/// Getting an ELM327 talking to a particular car. Cheap adapters often fail the automatic protocol search even
/// when the car is fine (a Mach-E answers instantly once CAN is chosen by hand), so after auto-detect fails each
/// protocol is tried explicitly.
enum ElmProtocol {
    /// Cars from about 2008 on use CAN (6/7 are 500 kbit, 8/9 are 250). Older ones use ISO 9141 / KWP / J1850:
    /// 3 ISO 9141-2, 5 KWP fast, 4 KWP slow, 1 J1850 PWM, 2 J1850 VPW.
    static func order(forYear year: Int?) -> [String] {
        (year ?? 0) >= 2008 ? ["6", "7", "8", "9"] : ["3", "5", "4", "6", "1", "2"]
    }

    /// The adapter's answer to a Mode 01 request that means "I couldn't talk to the car".
    static func failed(_ reply: String) -> Bool {
        let t = reply.uppercased()
        return reply.isEmpty || t.contains("UNABLE") || t.contains("NO DATA") || t.contains("CAN ERROR")
            || t.contains("BUS INIT") || t.contains("BUS BUSY") || t.contains("ERROR") || t.contains("?")
    }

    /// Auto-detect first (it can take 10 to 20 seconds on older cars), then each protocol in [order]. Returns the
    /// car's reply to 0100, or the last failure.
    static func establish(link: ElmLink, order: [String]) async -> String {
        var probe = (try? await link.send("0100", timeout: 30)) ?? ""
        Diag.log("auto-detect probe: \(probe)")
        guard failed(probe) else { return probe }
        for p in order {
            _ = try? await link.send("ATSP\(p)", timeout: 3)
            probe = (try? await link.send("0100", timeout: 10)) ?? ""
            Diag.log("protocol \(p) probe: \(probe)")
            if !failed(probe) { return probe }
        }
        return probe
    }

    /// One module's reply when headers are on: "7E8 06 41 00 AA 08 20 13", or with spaces off "7E8064100AA082013".
    struct CanReply: Equatable {
        /// The responding module's id, e.g. "7E8".
        let module: String
        /// The payload after the length byte (the mode and PID echo first).
        let data: [Int]
    }

    /// Single-frame replies only, which is all a Mode 01 request produces.
    static func canReplies(_ reply: String) -> [CanReply] {
        reply.split(whereSeparator: \.isNewline).compactMap { raw in
            let s = raw.filter { !$0.isWhitespace }
            guard s.count >= 7, s.hasPrefix("7E"), let id = Int(s.prefix(3), radix: 16), (0x7E8...0x7EF).contains(id) else { return nil }
            let rest = Array(s.dropFirst(3))
            guard let length = Int(String(rest[0...1]), radix: 16), (1...7).contains(length) else { return nil }
            let payload = stride(from: 2, to: rest.count - 1, by: 2).compactMap { Int(String(rest[$0...$0 + 1]), radix: 16) }
            guard payload.count >= length else { return nil }
            return CanReply(module: String(s.prefix(3)), data: Array(payload.prefix(length)))
        }
    }

    /// The address to send a request to so that a given module (by its reply id) answers: 7E8 -> 7E0, 7EC -> 7E4.
    static func requestAddress(forResponse id: String) -> String? {
        guard let n = Int(id, radix: 16), (0x7E8...0x7EF).contains(n) else { return nil }
        return String(format: "%X", n - 8)
    }
}
