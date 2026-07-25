import SwiftUI

struct DependencyRow: View {
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let dependency: ModDependency

    var body: some View {
        let status = modsStore.resolveDependencyStatus(for: dependency.uniqueId)

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dependency.uniqueId.rawValue)
                    .font(.system(size: 13, weight: .bold))
                if dependency.isRequired {
                    Text(localizationStore.L(L10n.ModDetailExtra.required))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                } else {
                    Text(localizationStore.L(L10n.ModDetailExtra.optional))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
            }

            Spacer()

            switch status {
            case .active:
                Label(localizationStore.L(L10n.ModDetailExtra.installedAndEnabled), systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .medium))
            case .disabled(let mod):
                Button {
                    appCoordinator.toggleMod(mod)
                } label: {
                    Label(localizationStore.L(L10n.ModDetailExtra.enableMod), systemImage: "power")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(6)
            case .missing:
                Button {
                    if let url = URL(string: "https://www.nexusmods.com/stardewvalley/search/?gsearch=\(dependency.uniqueId.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(localizationStore.L(L10n.ModDetailExtra.searchNexus), systemImage: "magnifyingglass")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
