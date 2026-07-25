import SwiftUI

/// macOS System Settings-style sidebar row.
struct SidebarNavItem: View {
    let icon: String
    let iconColor: Color
    let label: String
    let tab: String
    @Binding var currentTab: String
    @State private var isHovered = false

    var isSelected: Bool { currentTab == tab }

    var body: some View {
        Button(action: { currentTab = tab }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20, alignment: .center)

                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                          ? Color.accentColor
                          : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("sidebar-tab-\(tab)")
        .onHover { isHovered = $0 }
        .pointingHandCursor()
    }
}
