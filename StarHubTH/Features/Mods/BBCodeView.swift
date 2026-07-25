import SwiftUI

struct BBCodeView: View {
    let blocks: [LiveNexusAPIClient.DescriptionBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let txt):
                    Text(.init(txt))
                        .font(.body)
                        .textSelection(.enabled)
                case .image(let url):
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit().frame(maxHeight: 400).cornerRadius(8)
                        } else if phase.error != nil {
                            Text("Failed to load image").foregroundColor(.red).font(.caption)
                        } else {
                            ProgressView()
                        }
                    }
                case .spoiler(let title, let content):
                    SpoilerView(title: title, content: content)
                }
            }
        }
    }
}
