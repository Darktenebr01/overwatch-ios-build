import Foundation

struct API {
    static let team = "overwatch"

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "" }
        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    static func register(server: String, name: String, employeeId: String) async throws -> String {
        let body: [String: Any] = [
            "team_code": team,
            "employee_id": employeeId,
            "name": name,
            "app": "workday-ios"
        ]
        let response: TokenResponse = try await request(server: server, path: "/api/register",
                                                        method: "POST", body: body)
        return response.token
    }

    static func config(server: String, token: String) async throws -> ConfigResponse {
        try await request(server: server, path: "/api/config", token: token)
    }

    static func team(server: String, adminKey: String, month: String) async throws -> TeamResponse {
        let today = Self.dateString(Date())
        let path = "/api/admin/team?team_code=\(team)&month=\(month)&today=\(today)"
        return try await request(server: server, path: path, adminKey: adminKey)
    }

    static func saveGeofence(server: String, adminKey: String, kind: String,
                             name: String, lat: Double, lng: Double,
                             radiusM: Double, autoMiles: Double, autoHours: Double) async throws {
        let body: [String: Any] = [
            "team_code": team,
            "kind": kind,
            "name": name,
            "lat": lat,
            "lng": lng,
            "radius_m": radiusM,
            "auto_work_miles": autoMiles,
            "auto_work_hours": autoHours
        ]
        let _: OkResponse = try await request(server: server, path: "/api/admin/geofence",
                                              method: "POST", adminKey: adminKey, body: body)
    }

    static func clearGeofence(server: String, adminKey: String, kind: String) async throws {
        let _: OkResponse = try await request(
            server: server,
            path: "/api/admin/geofence?team_code=\(team)&kind=\(kind)",
            method: "DELETE",
            adminKey: adminKey
        )
    }

    static func postWorkday(server: String, token: String, date: String) async throws {
        let _: OkResponse = try await request(server: server, path: "/api/workdays",
                                              method: "POST", token: token, body: ["date": date])
    }

    static func deleteWorkday(server: String, token: String, date: String) async throws {
        let _: OkResponse = try await request(server: server, path: "/api/workdays/\(date)",
                                              method: "DELETE", token: token)
    }

    static func postLocation(server: String, token: String, lat: Double, lng: Double,
                             accuracy: Double, recordedAt: Int64) async throws {
        let body: [String: Any] = [
            "lat": lat,
            "lng": lng,
            "accuracy": accuracy,
            "recorded_at": recordedAt
        ]
        let _: OkResponse = try await request(server: server, path: "/api/location",
                                              method: "POST", token: token, body: body)
    }

    static func request<T: Decodable>(server: String, path: String, method: String = "GET",
                                      token: String? = nil, adminKey: String? = nil,
                                      body: [String: Any]? = nil) async throws -> T {
        let base = normalize(server)
        guard !base.isEmpty, let url = URL(string: base + path) else {
            throw APIError(message: "Server URL is not valid")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Workday-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let adminKey, !adminKey.isEmpty {
            request.setValue(adminKey, forHTTPHeaderField: "X-Admin-Key")
        }
        if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "No server response")
        }
        guard (200..<300).contains(http.statusCode) else {
            var message = "Server \(http.statusCode)"
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = object["error"] as? String {
                message += ": \(detail)"
            }
            throw APIError(message: message)
        }
        if data.isEmpty {
            throw APIError(message: "Server returned an empty response")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func monthString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}
