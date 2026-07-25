import SwiftUI

struct SpoilerView: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    let title: String
    let content: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                    let displayTitle = (title.isEmpty || title == "tag_show_spoiler") ? localizationStore.L(L10n.Tags.spoiler) : title
                    Text(displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(isExpanded ? "Hide" : "Show")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .pointingHandCursor()

            if isExpanded {
                Text(.init(content))
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}
