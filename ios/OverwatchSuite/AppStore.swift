import Foundation
import CoreLocation

@MainActor
final class AppStore: ObservableObject {
    @Published var mode: String?
    @Published var server: String
    @Published var name: String
    @Published var employeeId: String
    @Published var token: String
    @Published var adminKey: String
    @Published var live: Bool
    @Published var workdays: Set<String>
    @Published var pending: Set<String>
    @Published var deleted: Set<String>
    @Published var home: Geofence?
    @Published var autoMiles: Double
    @Published var autoHours: Double
    @Published var team: [Person]
    @Published var school: Geofence?
    @Published var events: [GeoEvent]
    @Published var status: String
    @Published var adminStatus: String
    @Published var lastLocation: CLLocation?
    @Published var authorization: CLAuthorizationStatus

    let location = LocationController()
    private var awaySince: Date?
    private var lastPost = Date.distantPast
    private var lastPosted: CLLocation?
    private let defaults = UserDefaults.standard

    init() {
        mode = defaults.string(forKey: "mode")
        server = defaults.string(forKey: "server") ?? ""
        name = defaults.string(forKey: "name") ?? ""
        adminKey = defaults.string(forKey: "adminKey") ?? ""
        token = defaults.string(forKey: "token") ?? ""
        live = defaults.bool(forKey: "live")
        workdays = Set(defaults.stringArray(forKey: "workdays") ?? [])
        pending = Set(defaults.stringArray(forKey: "pending") ?? [])
        deleted = Set(defaults.stringArray(forKey: "deleted") ?? [])
        autoMiles = defaults.double(forKey: "autoMiles")
        autoHours = defaults.double(forKey: "autoHours")
        team = []
        school = nil
        events = []
        status = ""
        adminStatus = ""
        authorization = .notDetermined
        if let data = defaults.data(forKey: "home"),
           let fence = try? JSONDecoder().decode(Geofence.self, from: data) {
            home = fence
        } else {
            home = nil
        }
        if let id = defaults.string(forKey: "employeeId"), !id.isEmpty {
            employeeId = id
        } else {
            let id = "WD-" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
            employeeId = String(id)
            defaults.set(employeeId, forKey: "employeeId")
        }
        if defaults.object(forKey: "awaySince") != nil {
            awaySince = Date(timeIntervalSince1970: defaults.double(forKey: "awaySince"))
        }
        location.onLocation = { [weak self] loc in
            Task { @MainActor in self?.handleLocation(loc) }
        }
        location.onHomeExit = { [weak self] in
            Task { @MainActor in self?.handleHomeExit() }
        }
        location.onHomeEnter = { [weak self] in
            Task { @MainActor in self?.handleHomeEnter() }
        }
        location.onAuthorizationChanged = { [weak self] status in
            Task { @MainActor in self?.authorization = status }
        }
        location.onError = { [weak self] message in
            Task { @MainActor in self?.status = message }
        }
        location.monitorHome(home)
    }

    func selectMode(_ newMode: String) {
        mode = newMode
        defaults.set(newMode, forKey: "mode")
        if newMode == "workday" {
            location.monitorHome(home)
            if live { location.startLive() }
        } else {
            location.stopLive()
        }
    }

    func leaveMode() {
        mode = nil
        defaults.removeObject(forKey: "mode")
        location.stopLive()
    }

    func setServer(_ raw: String) {
        let normalized = API.normalize(raw)
        guard normalized != server else { return }
        server = normalized
        token = ""
        defaults.set(server, forKey: "server")
        defaults.removeObject(forKey: "token")
        pending = workdays
        save()
    }

    func saveName(_ value: String) {
        name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(name, forKey: "name")
    }

    func saveAdminKey(_ value: String) {
        adminKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(adminKey, forKey: "adminKey")
    }

    func bootstrap() async {
        authorization = location.authorizationStatus
        if mode == "admin" {
            if !adminKey.isEmpty { await refreshAdmin() }
            return
        }
        location.monitorHome(home)
        if !server.isEmpty && !name.isEmpty {
            await syncWorkday()
        }
    }

    func syncWorkday() async {
        guard !server.isEmpty, !name.isEmpty else {
            status = "Set your name and server first."
            return
        }
        status = "Syncing…"
        do {
            if token.isEmpty {
                token = try await API.register(server: server, name: name, employeeId: employeeId)
                defaults.set(token, forKey: "token")
            }
            let config = try await API.config(server: server, token: token)
            applyConfig(config.homeGeofence)
            for date in Array(pending) {
                try await API.postWorkday(server: server, token: token, date: date)
                pending.remove(date)
            }
            for date in Array(deleted) {
                try await API.deleteWorkday(server: server, token: token, date: date)
                deleted.remove(date)
            }
            save()
            status = "Synced \(workdays.count) day\(workdays.count == 1 ? "" : "s")."
        } catch {
            status = error.localizedDescription
        }
    }

    private func applyConfig(_ fence: Geofence?) {
        home = fence
        autoMiles = fence?.autoWorkMiles ?? 0
        autoHours = fence?.autoWorkHours ?? 0
        if let fence, let data = try? JSONEncoder().encode(fence) {
            defaults.set(data, forKey: "home")
        } else {
            defaults.removeObject(forKey: "home")
        }
        defaults.set(autoMiles, forKey: "autoMiles")
        defaults.set(autoHours, forKey: "autoHours")
        location.monitorHome(fence)
    }

    func toggleLive(_ on: Bool) {
        live = on
        defaults.set(on, forKey: "live")
        if on {
            location.requestAlways()
            location.startLive()
            status = "Location sharing on."
        } else {
            location.stopLive()
            awaySince = nil
            defaults.removeObject(forKey: "awaySince")
            status = "Location sharing off."
        }
    }

    private func handleHomeExit() {
        guard mode == "workday", home != nil else { return }
        live = true
        defaults.set(true, forKey: "live")
        location.startLive()
        status = "Left home. Sharing started."
        Task { await syncWorkday() }
    }

    private func handleHomeEnter() {
        guard mode == "workday", home != nil else { return }
        live = false
        defaults.set(false, forKey: "live")
        location.stopLive()
        awaySince = nil
        defaults.removeObject(forKey: "awaySince")
        status = "Home. Sharing stopped."
    }

    private func handleLocation(_ location: CLLocation) {
        lastLocation = location
        guard live else { return }
        evaluateAutoWork(location)
        let distance = lastPosted.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
        guard Date().timeIntervalSince(lastPost) >= 30 || distance >= 40 else { return }
        lastPost = Date()
        lastPosted = location
        let recorded = Int64(location.timestamp.timeIntervalSince1970 * 1000)
        Task {
            do {
                try await API.postLocation(server: server, token: token,
                                           lat: location.coordinate.latitude,
                                           lng: location.coordinate.longitude,
                                           accuracy: max(0, location.horizontalAccuracy),
                                           recordedAt: recorded)
            } catch {
                // The next location update retries.
            }
        }
    }

    private func evaluateAutoWork(_ location: CLLocation) {
        guard let fence = home, autoMiles > 0 else { return }
        let homeLocation = CLLocation(latitude: fence.lat, longitude: fence.lng)
        let miles = location.distance(from: homeLocation) / 1609.344
        guard miles >= autoMiles else {
            awaySince = nil
            defaults.removeObject(forKey: "awaySince")
            return
        }
        let today = API.dateString(Date())
        if workdays.contains(today) {
            awaySince = nil
            defaults.removeObject(forKey: "awaySince")
            return
        }
        if autoHours <= 0 {
            addWorkday(today)
            return
        }
        if awaySince == nil {
            awaySince = Date()
            defaults.set(awaySince!.timeIntervalSince1970, forKey: "awaySince")
            return
        }
        if Date().timeIntervalSince(awaySince!) >= autoHours * 3600 {
            addWorkday(today)
            awaySince = nil
            defaults.removeObject(forKey: "awaySince")
        }
    }

    func addWorkday(_ date: String = API.dateString(Date())) {
        workdays.insert(date)
        pending.insert(date)
        deleted.remove(date)
        save()
        status = "Work Day recorded."
        Task { await syncWorkday() }
    }

    func removeWorkday(_ date: String = API.dateString(Date())) {
        workdays.remove(date)
        pending.remove(date)
        deleted.insert(date)
        save()
        status = "Work Day removed."
        Task { await syncWorkday() }
    }

    func countMonth(_ date: Date = Date()) -> Int {
        let prefix = API.monthString(date)
        return workdays.filter { $0.hasPrefix(prefix) }.count
    }

    func dayCount() -> Int { workdays.count }

    func refreshAdmin() async {
        guard !server.isEmpty, !adminKey.isEmpty else {
            adminStatus = "Set the server and admin key."
            return
        }
        adminStatus = "Loading…"
        do {
            let response = try await API.team(server: server, adminKey: adminKey,
                                              month: API.monthString(Date()))
            team = response.employees
            school = response.geofence
            home = response.homeGeofence
            events = response.events ?? []
            adminStatus = "Updated \(Self.timeString())."
        } catch {
            adminStatus = error.localizedDescription
        }
    }

    func saveGeofence(kind: String, name: String, lat: Double, lng: Double,
                      radius: Double, autoMiles: Double, autoHours: Double) async {
        do {
            try await API.saveGeofence(server: server, adminKey: adminKey, kind: kind,
                                       name: name, lat: lat, lng: lng, radiusM: radius,
                                       autoMiles: autoMiles, autoHours: autoHours)
            await refreshAdmin()
        } catch {
            adminStatus = error.localizedDescription
        }
    }

    func clearGeofence(kind: String) async {
        do {
            try await API.clearGeofence(server: server, adminKey: adminKey, kind: kind)
            await refreshAdmin()
        } catch {
            adminStatus = error.localizedDescription
        }
    }

    private func save() {
        defaults.set(Array(workdays), forKey: "workdays")
        defaults.set(Array(pending), forKey: "pending")
        defaults.set(Array(deleted), forKey: "deleted")
    }

    static func timeString() -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
