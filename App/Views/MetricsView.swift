import SwiftUI

/// Power and cadence as the trainer reports them.
struct MetricsView: View {
    let power: Int?
    let cadence: Int?

    var body: some View {
        HStack {
            metric(power, unit: "W", name: "Power")
            metric(cadence, unit: "rpm", name: "Cadence")
        }
    }

    private func metric(_ value: Int?, unit: String, name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 48, weight: .bold).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(value == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            Text(unit)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? "No data")
    }
}
