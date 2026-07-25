import SwiftUI

/// One editable row in the config visual editor — a boolean toggle or a numeric
/// stepper+field, depending on `item.type`. `onChange` hands back the whole updated item
/// rather than mutating in place, since this view doesn't own `configItems`.
struct ConfigFieldRow: View {
    let item: ConfigItem
    let label: String
    let onChange: (ConfigItem) -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()

            switch item.type {
            case .boolean:
                Toggle("", isOn: Binding(
                    get: { item.boolValue },
                    set: { newValue in
                        var updated = item
                        updated.boolValue = newValue
                        onChange(updated)
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .controlSize(.small)
                .labelsHidden()

            case .number:
                if item.isInt {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(
                            get: { Int(item.numberValue) },
                            set: { newValue in
                                var updated = item
                                updated.numberValue = Double(newValue)
                                onChange(updated)
                            }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)

                        Stepper("", onIncrement: {
                            var updated = item
                            updated.numberValue += 1
                            onChange(updated)
                        }, onDecrement: {
                            var updated = item
                            updated.numberValue -= 1
                            onChange(updated)
                        })
                        .labelsHidden()
                    }
                } else {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(
                            get: { item.numberValue },
                            set: { newValue in
                                var updated = item
                                updated.numberValue = newValue
                                onChange(updated)
                            }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)

                        Stepper("", onIncrement: {
                            var updated = item
                            updated.numberValue += 0.5
                            onChange(updated)
                        }, onDecrement: {
                            var updated = item
                            updated.numberValue -= 0.5
                            onChange(updated)
                        })
                        .labelsHidden()
                    }
                }
            default:
                EmptyView()
            }
        }
        .padding(.vertical, 8)
    }
}
