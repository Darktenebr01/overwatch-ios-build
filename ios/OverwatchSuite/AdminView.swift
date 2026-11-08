import SwiftUI
import MapKit

struct AdminView: View {
    @EnvironmentObject private var store: AppStore
    @State private var serverDraft = ""
    @State private var keyDraft = ""
    @State private var center = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35)
    @State private var editor: GeofenceEditorConfig?
    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if store.adminKey.isEmpty {
                    login
                } else {
                    dashboard
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Roles") { store.leaveMode() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(item: $editor) { config in
                GeofenceEditorView(config: config)
                    .environmentObject(store)
            }
            .task {
                serverDraft = store.server
                keyDraft = store.adminKey
                await store.refreshAdmin()
            }
            .onReceive(timer) { _ in
                guard !store.adminKey.isEmpty else { return }
                Task { await store.refreshAdmin() }
            }
        }
    }

    private var login: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Kicker(text: "Overwatch / Admin")
                Text("Know the day.\nSee the field.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
                Card {
                    Kicker(text: "Connection")
                    Text("Overwatch server").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                    Text("The team is built into this app. Only the server and admin key are needed.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    TextField("https://your-server", text: $serverDraft)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(10).background(Theme.bg).clipShape(RoundedRectangle(cornerRadius: 10))
                    SecureField("Admin key", text: $keyDraft)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(10).background(Theme.bg).clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        store.setServer(serverDraft)
                        store.saveAdminKey(keyDraft)
                        Task { await store.refreshAdmin() }
                    } label: {
                        Text("SAVE & CONNECT").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.bg).frame(maxWidth: .infinity)
                            .padding(.vertical, 14).background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    Text(store.adminStatus).font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }
            .padding(18)
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                stats
                mapCard
                geofenceCard(kind: "school", title: "School geofence", fence: store.school)
                geofenceCard(kind: "home", title: "Home geofence", fence: store.home)
                qrCard
                teamCard
                eventsCard
            }
            .padding(18)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Kicker(text: "Overwatch / Team Ops")
            Text("Team field").font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(monthLabel(Date())).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("TEAM", "\(store.team.count)")
            stat("WORKING", "\(store.team.filter(\.today).count)")
            stat("SHARING", "\(store.team.filter(\.sharing).count)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var mapCard: some View {
        Card {
            HStack {
                Kicker(text: "Live map")
                Spacer()
                Button("REFRESH") { Task { await store.refreshAdmin() } }
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
            }
            AdminMapView(people: store.team, school: store.school, home: store.home, center: $center)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Pan the map to a location before setting a geofence. Amber = school, teal = home, dashed yellow = auto Work Day distance.")
                .font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
    }

    private func geofenceCard(kind: String, title: String, fence: Geofence?) -> some View {
        Card {
            HStack {
                Kicker(text: title)
                Spacer()
                if fence != nil {
                    Button("CLEAR") {
                        Task { await store.clearGeofence(kind: kind) }
                    }
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
                }
            }
            Text(fenceText(fence))
                .font(.system(size: 12)).foregroundStyle(fence == nil ? Theme.muted : Theme.accent)
            Button {
                editor = GeofenceEditorConfig(kind: kind, center: center, existing: fence)
            } label: {
                Text("SET FROM MAP CENTER").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.bg).frame(maxWidth: .infinity)
                    .padding(.vertical, 12).background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var qrCard: some View {
        Card {
            Kicker(text: "Workday setup QR")
            if let payload = qrPayload, let image = QRCodeGenerator.image(for: payload) {
                Image(uiImage: image)
                    .interpolation(.none).resizable().scaledToFit()
                    .frame(maxWidth: 230).frame(maxWidth: .infinity)
                    .padding(10).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Employees: Workday → Scan QR. Contains only the server address.")
                    .font(.system(size: 10)).foregroundStyle(Theme.muted)
            } else {
                Text("Set a server address to generate the QR.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
    }

    private var teamCard: some View {
        Card {
            Kicker(text: "Team")
            if store.team.isEmpty {
                Text("No team data yet. Press Refresh after a Workday phone syncs.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            } else {
                ForEach(store.team) { person in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                            Text("\(person.monthDays) days this month" + (person.today ? " · worked today" : ""))
                                .font(.system(size: 10)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(person.sharing ? "LIVE" : (person.today ? "TODAY" : "OFF"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(person.sharing ? Theme.accent : Theme.muted)
                    }
                    .padding(.vertical, 4)
                }
            }
            Text(store.adminStatus).font(.system(size: 9)).foregroundStyle(Theme.muted)
        }
    }

    private var eventsCard: some View {
        Card {
            Kicker(text: "Recent alerts")
            if store.events.isEmpty {
                Text("No arrival or departure alerts yet.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            } else {
                ForEach(store.events.prefix(8)) { event in
                    Text(event.title + " · " + eventTime(event.occurredAt))
                        .font(.system(size: 11))
                        .foregroundStyle(event.kind == "arrival" ? Theme.accent : Theme.muted)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private var qrPayload: String? {
        guard !store.server.isEmpty else { return nil }
        let config = QRConfig(type: "workday-setup", version: 1, server: API.normalize(store.server))
        guard let data = try? JSONEncoder().encode(config) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func fenceText(_ fence: Geofence?) -> String {
        guard let fence else { return "Not set." }
        var text = String(format: "%@ · %.5f, %.5f · %.0f m", fence.name, fence.lat, fence.lng, fence.radiusM)
        if fence.autoWorkMiles > 0 {
            text += String(format: " · auto %.1f mi", fence.autoWorkMiles)
            if fence.autoWorkHours > 0 { text += String(format: " / %.1f h", fence.autoWorkHours) }
        }
        return text
    }

    private func eventTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

struct GeofenceEditorConfig: Identifiable {
    let id = UUID()
    let kind: String
    let center: CLLocationCoordinate2D
    let existing: Geofence?
}

struct GeofenceEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let config: GeofenceEditorConfig

    @State private var name: String
    @State private var radius: String
    @State private var miles: String
    @State private var hours: String
    @State private var lat: String
    @State private var lng: String

    init(config: GeofenceEditorConfig) {
        self.config = config
        let existing = config.existing
        _name = State(initialValue: existing?.name ?? (config.kind == "home" ? "Home" : "School"))
        _radius = State(initialValue: String(format: "%.0f", existing?.radiusM ?? (config.kind == "home" ? 150 : 250)))
        _miles = State(initialValue: String(format: "%.1f", existing?.autoWorkMiles ?? 0))
        _hours = State(initialValue: String(format: "%.1f", existing?.autoWorkHours ?? 0))
        _lat = State(initialValue: String(format: "%.6f", existing?.lat ?? config.center.latitude))
        _lng = State(initialValue: String(format: "%.6f", existing?.lng ?? config.center.longitude))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Geofence") {
                    TextField("Name", text: $name)
                    TextField("Radius (m)", text: $radius).keyboardType(.decimalPad)
                    TextField("Latitude", text: $lat).keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $lng).keyboardType(.numbersAndPunctuation)
                }
                if config.kind == "home" {
                    Section("Auto Work Day") {
                        TextField("Miles from home (0 = off)", text: $miles).keyboardType(.decimalPad)
                        TextField("Hours away before counting", text: $hours).keyboardType(.decimalPad)
                    }
                }
                Section {
                    Button("Save geofence") { save() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(config.kind == "home" ? "Home geofence" : "School geofence")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard let radiusValue = Double(radius), let latValue = Double(lat), let lngValue = Double(lng),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let milesValue = config.kind == "home" ? (Double(miles) ?? 0) : 0
        let hoursValue = config.kind == "home" ? (Double(hours) ?? 0) : 0
        Task {
            await store.saveGeofence(kind: config.kind, name: name, lat: latValue, lng: lngValue,
                                     radius: radiusValue, autoMiles: milesValue, autoHours: hoursValue)
            dismiss()
        }
    }
}
