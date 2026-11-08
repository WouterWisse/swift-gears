import SwiftUI

/// Easier and harder on screen, with a haptic tap for each.
struct ShiftButtons: View {
    let shift: (Int) -> Void
    @State private var easierTaps = 0
    @State private var harderTaps = 0

    var body: some View {
        HStack(spacing: 12) {
            button("Easier", symbol: "minus") {
                easierTaps += 1
                shift(-1)
            }
            .sensoryFeedback(.decrease, trigger: easierTaps)

            button("Harder", symbol: "plus") {
                harderTaps += 1
                shift(1)
            }
            .sensoryFeedback(.increase, trigger: harderTaps)
        }
    }

    private func button(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .bold))
                    .frame(height: 34)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(ShiftButtonStyle())
    }
}

private struct ShiftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(.secondarySystemFill)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
