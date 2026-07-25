import SwiftUI

struct ModUpdateBanner: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text(String(format: localizationStore.L(L10n.Mods.updateCount), Int64(modsStore.outOfDateMods.count)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .pointingHandCursor()
            .background(Color.blue.opacity(0.06))

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(modsStore.outOfDateMods) { update in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text("→ \(update.version)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                if let url = URL(string: update.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                    Text(localizationStore.L(L10n.Mods.updateMod))
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandCursor()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.03))

                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }
}
