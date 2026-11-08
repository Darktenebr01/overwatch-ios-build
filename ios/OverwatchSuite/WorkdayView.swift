import SwiftUI

struct WorkdayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var serverDraft = ""
    @State private var nameDraft = ""
    @State private var showScanner = false
    @State private var showSettings = false

    private var today: String { API.dateString(Date()) }
    private var logged: Bool { store.workdays.contains(today) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayCard
                    totalsCard
                    locationCard
                    settingsCard
                    footer
                }
                .padding(18)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Roles") { store.leaveMode() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $showScanner) {
                ZStack(alignment: .topTrailing) {
                    QRScannerView { code in
                        showScanner = false
                        applyQR(code)
                    }
                    .ignoresSafeArea()
                    Button("Close") { showScanner = false }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(18)
                }
            }
            .task {
                serverDraft = store.server
                nameDraft = store.name
                await store.bootstrap()
            }
            .onChange(of: store.server) { _, value in serverDraft = value }
            .onChange(of: store.name) { _, value in nameDraft = value }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(text: "Workday / Time sheet")
            Text("Your work,\ncounted.")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayCard: some View {
        Card {
            HStack {
                Kicker(text: "Today")
                Spacer()
                Text(weekday(Date()))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.amber)
                    .clipShape(Capsule())
            }
            Text(longDate(Date()))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(logged ? "Today is a Work Day. It is already on your local record." : "Tap once and today becomes a Work Day.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            Button {
                if logged {
                    store.removeWorkday(today)
                } else {
                    store.addWorkday(today)
                }
            } label: {
                Text(logged ? "WORK DAY LOGGED ✓" : "CLOCK IN — WORK DAY")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(logged ? Theme.amber : Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(logged ? Color.white.opacity(0.06) : Theme.amber)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)

            if logged {
                Button("Remove today's Work Day") { store.removeWorkday(today) }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var totalsCard: some View {
        Card {
            Kicker(text: "Monthly totals")
            Text("Every worked day, by month")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthLabel(Date())).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Text("\(store.countMonth()) days")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.amber)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("All time").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Text("\(store.dayCount()) days")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.text)
                }
            }
        }
    }

    private var locationCard: some View {
        Card {
            Kicker(text: "Live location")
            Toggle("Share my live location with my team", isOn: Binding(
                get: { store.live },
                set: { store.toggleLive($0) }
            ))
            .tint(Theme.accent)
            .foregroundStyle(Theme.text)

            Text(locationText)
                .font(.system(size: 11))
                .foregroundStyle(store.live ? Theme.accent : Theme.muted)

            if let home = store.home {
                Text("Home automation: \(home.name) · share starts on exit, stops on return.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                if store.autoMiles > 0 {
                    Text(String(format: "Auto Work Day: %.1f mi from home", store.autoMiles)
                         + (store.autoHours > 0 ? String(format: " after %.1f h away.", store.autoHours) : " immediately."))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.amber)
                }
            } else {
                Text("No home geofence yet. Set it in Overwatch, then sync here.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var settingsCard: some View {
        Card {
            Kicker(text: "Connection")
            Text("Connect to Overwatch")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Only your name is needed. Employee ID and team are assigned automatically.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)

            labelled("Server") {
                TextField("https://your-server", text: $serverDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(10)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { store.setServer(serverDraft) }
            }
            HStack(spacing: 8) {
                Button("SAVE SERVER") {
                    store.setServer(serverDraft)
                    Task { await store.syncWorkday() }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.accent)
                Button("SCAN QR") { showScanner = true }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            labelled("Your name") {
                TextField("Alex Morgan", text: $nameDraft)
                    .padding(10)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { store.saveName(nameDraft) }
            }

            Button {
                store.saveName(nameDraft)
                Task { await store.syncWorkday() }
            } label: {
                Text("SAVE & SYNC")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Text(store.status)
                .font(.system(size: 10))
                .foregroundStyle(store.status.lowercased().contains("fail") ? Theme.danger : Theme.muted)
        }
    }

    private var footer: some View {
        Text("Workday stores the record on this phone first. The Overwatch server lets your team see it. Background tracking is visible in the iOS status bar and can be stopped in the app.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private var locationText: String {
        switch store.authorization {
        case .authorizedAlways:
            return store.live ? "Sharing · background location allowed." : "Off. Background location is allowed for home automation."
        case .authorizedWhenInUse:
            return store.live ? "Sharing while the app is open. Choose Always for home automation." : "Off. Choose Always for home automation."
        case .denied, .restricted:
            return "Location permission denied. Enable it in Settings."
        default:
            return "Location permission not requested yet."
        }
    }

    private func applyQR(_ code: String) {
        guard let data = code.data(using: .utf8),
              let config = try? JSONDecoder().decode(QRConfig.self, from: data),
              config.type == "workday-setup" else {
            store.status = "That is not a Workday setup QR."
            return
        }
        serverDraft = API.normalize(config.server)
        store.setServer(serverDraft)
        store.status = "Server loaded from QR. Tap Save & Sync."
    }

    @ViewBuilder
    private func labelled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.muted)
            content()
        }
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: date)
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
