import SwiftUI

struct StatusFilterPills: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore

    private var options: [(ModFilterStatus, String)] {[
        (.all,      localizationStore.L(L10n.Mods.filterAll)),
        (.enabled,  localizationStore.L(L10n.Mods.filterEnabled)),
        (.disabled, localizationStore.L(L10n.Mods.filterDisabled)),
    ]}

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0.rawValue) { status, label in
                Button {
                    modsStore.modFilterStatus = status
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: modsStore.modFilterStatus == status ? .semibold : .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                        .foregroundColor(modsStore.modFilterStatus == status ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(modsStore.modFilterStatus == status ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandCursor()
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
