import SwiftUI

struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 8)
            .padding(.top, 8)
            .padding(.bottom, 0)
    }
}
