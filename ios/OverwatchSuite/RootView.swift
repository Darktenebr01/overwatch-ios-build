import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Group {
                if store.mode == "workday" {
                    WorkdayView()
                        .environmentObject(store)
                } else if store.mode == "admin" {
                    AdminView()
                        .environmentObject(store)
                } else {
                    ModePicker()
                        .environmentObject(store)
                }
            }
        }
        .task { await store.bootstrap() }
    }
}

private struct ModePicker: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 30)
            Kicker(text: "Overwatch Suite")
            Text("Know the day.\nSee the field.")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("Install this unsigned iOS build on both phones. Choose the role for this phone.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)

            Button {
                store.selectMode("workday")
            } label: {
                RoleRow(icon: "clock.fill", title: "Workday",
                        subtitle: "Clock in, count workdays, share location.")
            }
            .buttonStyle(.plain)

            Button {
                store.selectMode("admin")
            } label: {
                RoleRow(icon: "map.fill", title: "Overwatch Admin",
                        subtitle: "Team totals, map, school and home geofences.")
            }
            .buttonStyle(.plain)

            if let mode = store.mode {
                Text("Last role: \(mode == "workday" ? "Workday" : "Admin")")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(22)
    }
}

private struct RoleRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.bg)
                .frame(width: 46, height: 46)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
