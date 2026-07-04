import SwiftUI

struct LogsView: View {
    @ObservedObject var vm: StarHubTHViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                
                // ── Logs Section ──
                StandardSection(
                    title: vm.L(L10n.Logs.history),
                    footer: vm.L(L10n.Logs.historySubtitle)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(vm.L(L10n.Logs.systemLogs))
                                .font(.system(size: 13))
                            Spacer()
                            Button(vm.L(L10n.Logs.clearLogs)) {
                                vm.logOutput = ""
                            }
                        }
                        
                        Divider()
                        
                        // Log Console
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading) {
                                    if vm.logOutput.isEmpty {
                                        Text(vm.L(L10n.Logs.noLogs))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .italic()
                                    } else {
                                        Text(vm.logOutput)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Spacer().frame(height: 1).id("LogBottom")
                                }
                                .padding(12)
                            }
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                            .frame(minHeight: 200, maxHeight: 400)
                            .onChange(of: vm.logOutput) {
                                withAnimation {
                                    proxy.scrollTo("LogBottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // ── Troubleshooting tip card ──
                StandardSection(title: vm.L(L10n.Logs.macOSTips)) {
                    Text(vm.L(L10n.Logs.macOSTipsContent))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
            }
            .padding(40)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
