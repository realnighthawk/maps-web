import CoreLocation
import Foundation

enum Api<T> {
    case ok(T)
    case unauthorized
    /// The router has no instance for this user yet.
    case notProvisioned
    case retry(String)
    /// The server understood and said no; [code] is its machine-readable reason (e.g. NO_CHARGER_COVERAGE).
    case failed(code: String?, message: String)
}

struct Place: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

    static func == (a: Place, b: Place) -> Bool { a.id == b.id }
}

/// Thin HTTP layer shared by search/planning and ingest: Bearer auth, JSON in and out, status classification.
struct Http {
    let baseURL: String

    func send(_ method: String, _ path: String, token: String, body: Data? = nil, extraHeaders: [String: String] = [:],
              timeout: TimeInterval) async -> (code: Int, text: String)? {
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        extraHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else { return nil }
        return (http.statusCode, String(decoding: data, as: UTF8.self))
    }

    /// maps-engine errors look like {"error":{"code":"...","message":"..."}}; the router's are {"error":"..."}.
    static func errorOf(_ text: String) -> (code: String?, message: String?) {
        guard let j = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] else { return (nil, nil) }
        if let e = j["error"] as? [String: Any] {
            let c = e["code"] as? String, m = e["message"] as? String
            return (c?.isEmpty == false ? c : nil, m?.isEmpty == false ? m : nil)
        }
        if let s = j["error"] as? String { return (nil, s) }
        return (nil, nil)
    }

    static func classify<T>(_ code: Int, _ text: String, parse: (String) throws -> T) -> Api<T> {
        switch code {
        case 200...299:
            if let v = try? parse(text) { return .ok(v) }
            return .retry("unreadable response")
        case 401, 403: return .unauthorized
        case 404 where text.contains("no_tenant"): return .notProvisioned
        case 408, 429: return .retry("server returned \(code)")
        case 500...: if errorOf(text).code == nil { return .retry("server returned \(code)") }; fallthrough
        default:
            let (c, m) = errorOf(text)
            return .failed(code: c, message: m ?? "The server returned \(code).")
        }
    }
}

/// Search, planning and car registration against the user's own maps-engine, through the router.
struct MapsEngineAPI {
    let http: Http
    init(baseURL: String) { http = Http(baseURL: baseURL) }

    func searchPlaces(token: String, query: String, near: CLLocationCoordinate2D?) async -> Api<[Place]> {
        var q = "/maps/api/v1/places/search?q=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        if let near { q += "&lat=\(near.latitude)&lng=\(near.longitude)" }
        return await call("GET", q, token) { text in
            let j = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
            return (j?["places"] as? [[String: Any]] ?? []).compactMap { p in
                guard let id = p["id"] as? String, let name = p["name"] as? String,
                      let lat = p["lat"] as? Double, let lng = p["lng"] as? Double else { return nil }
                return Place(id: id, name: name, address: p["address"] as? String ?? "",
                             coordinate: .init(latitude: lat, longitude: lng))
            }
        }
    }

    func registerVin(token: String, vin: String) async -> Api<Void> {
        await call("POST", "/maps/api/v1/vehicles/from-vin", token, json: ["vin": vin]) { _ in }
    }

    func planRoute(token: String, request: [String: Any]) async -> Api<RoutePlan> {
        await call("POST", "/maps/api/v1/route/plan", token, json: request) { try PlanParser.parse($0) }
    }

    /// Replaces the planner's profile for this car (used to fill in what public data lacked).
    func putProfile(token: String, vin: String, profile: [String: Any]) async -> Api<Void> {
        await call("PUT", "/maps/api/v1/vehicles/\(vin)", token, json: profile) { _ in }
    }

    /// Removes a car from the server: its planner profile (by VIN, when it has one) and its garage entry. A car the
    /// server never had counts as removed.
    func removeCar(token: String, id: String, vin: String) async -> Api<Void> {
        func gone(_ r: Api<Void>) -> Bool {
            switch r { case .ok: true; case .failed(let code, _): code == "NOT_FOUND"; default: false }
        }
        let enc = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s }
        if !vin.isEmpty {
            let r = await call("DELETE", "/maps/api/v1/vehicles/\(enc(vin))", token) { _ in }
            if !gone(r) { return r }
        }
        let g = await call("DELETE", "/maps/api/v1/garage/vehicles/\(enc(id))", token) { _ in }
        return gone(g) ? .ok(()) : g
    }

    private func call<T>(_ method: String, _ path: String, _ token: String, json: [String: Any]? = nil,
                         parse: @escaping (String) throws -> T) async -> Api<T> {
        let body = json.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        // Planning calls routing, weather, chargers and fuel providers; give it room.
        guard let r = await http.send(method, path, token: token, body: body, timeout: 90) else {
            return .retry("network error")
        }
        return Http.classify(r.code, r.text, parse: parse)
    }
}
