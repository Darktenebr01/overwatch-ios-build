import Foundation

struct Person: Identifiable, Decodable {
    let employeeId: String
    let name: String
    let today: Bool
    let monthDays: Int
    let sharing: Bool
    let lastSeen: Int64?
    let lastLocation: LastLocation?

    var id: String { employeeId }
    var hasLocation: Bool { lastLocation != nil }

    enum CodingKeys: String, CodingKey {
        case employeeId = "employee_id"
        case name, today, sharing
        case monthDays = "month_days"
        case lastSeen = "last_seen"
        case lastLocation = "last_location"
    }
}

struct LastLocation: Decodable {
    let lat: Double
    let lng: Double
    let accuracy: Double?
    let recordedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case lat, lng, accuracy
        case recordedAt = "recorded_at"
    }
}

struct Geofence: Codable, Equatable {
    let name: String
    let lat: Double
    let lng: Double
    let radiusM: Double
    let autoWorkMiles: Double
    let autoWorkHours: Double

    enum CodingKeys: String, CodingKey {
        case name, lat, lng
        case radiusM = "radius_m"
        case autoWorkMiles = "auto_work_miles"
        case autoWorkHours = "auto_work_hours"
    }

    init(name: String, lat: Double, lng: Double, radiusM: Double,
         autoWorkMiles: Double = 0, autoWorkHours: Double = 0) {
        self.name = name
        self.lat = lat
        self.lng = lng
        self.radiusM = radiusM
        self.autoWorkMiles = autoWorkMiles
        self.autoWorkHours = autoWorkHours
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Home"
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        radiusM = try c.decodeIfPresent(Double.self, forKey: .radiusM) ?? 150
        autoWorkMiles = try c.decodeIfPresent(Double.self, forKey: .autoWorkMiles) ?? 0
        autoWorkHours = try c.decodeIfPresent(Double.self, forKey: .autoWorkHours) ?? 0
    }
}

struct GeoEvent: Identifiable, Decodable {
    let id: Int
    let name: String
    let kind: String
    let geofence: String?
    let occurredAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, kind, geofence
        case occurredAt = "occurred_at"
    }

    var title: String {
        let whereText = geofence == "home" ? "Home" : "School"
        return "\(name) · \(whereText) · \(kind == "arrival" ? "Arrived" : "Left")"
    }
}

struct TeamResponse: Decodable {
    let employees: [Person]
    let geofence: Geofence?
    let homeGeofence: Geofence?
    let events: [GeoEvent]?

    enum CodingKeys: String, CodingKey {
        case employees
        case geofence
        case homeGeofence = "home_geofence"
        case events
    }
}

struct ConfigResponse: Decodable {
    let homeGeofence: Geofence?

    enum CodingKeys: String, CodingKey {
        case homeGeofence = "home_geofence"
    }
}

struct TokenResponse: Decodable {
    let token: String
}

struct OkResponse: Decodable {
    let ok: Bool?
}

struct QRConfig: Codable {
    let type: String
    let version: Int
    let server: String
}
