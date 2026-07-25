import SwiftUI

struct ProfileRow: View {
    let profile: ModProfile
    let isActive: Bool
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Binding var selectedProfileForDetail: ModProfile?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Circular Avatar
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isActive ? .white : .primary)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                Text(localizationStore.L(isActive ? L10n.Profiles.inUse : L10n.Profiles.inactive))
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .secondary : .secondary)
            }

            Spacer()

            // Info button (or delete)
            Button(action: {
                selectedProfileForDetail = profile
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizationStore.L(L10n.Profiles.viewDetails))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onTapGesture {
            appCoordinator.applyProfile(id: profile.id)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
