import SwiftUI

struct ModGroupRow: View {
    let mod: Mod
    let children: [Mod]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ModListRow(mod: mod, isChild: false, isGroupHeader: true, isExpanded: $isExpanded)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { cIdx, child in
                        ModListRow(mod: child, isChild: true, isGroupHeader: false, isExpanded: .constant(false))
                        if cIdx < children.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 1)
                                .padding(.leading, 64)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}
