import GearsCore
import SwiftUI

/// The gear in the app's compressed black numerals, with "/ 24" when there is room.
struct GearText: View {
    let state: RideActivityAttributes.ContentState
    let size: CGFloat
    var showsCount = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size / 24) {
            Text("\(state.gear)")
                .font(.system(size: size, weight: .black).width(.compressed))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(state.gear)))
            if showsCount {
                Text("/ \(state.gearCount)")
                    .font(.system(size: size * 0.3, weight: .bold).width(.compressed))
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gear \(state.gear) of \(state.gearCount)")
    }
}

/// Power or cadence as in the app: "--" when the trainer reports none.
struct MetricText: View {
    let value: Int?
    let unit: String
    let name: String
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: size, weight: .bold).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(value == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? "No data")
    }
}

/// The app's gear ramp, small: 24 bars as tall as their ratio, orange up to the current gear.
struct ActivityGearRamp: View {
    let gear: Int
    let height: CGFloat

    private static let ratios = Gearbox.ratios

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Self.ratios.indices, id: \.self) { index in
                // Narrower than their slot, so even the easiest gears read as bars, not dots.
                Capsule()
                    .fill(index < gear ? Color.zwift : Color.primary.opacity(0.15))
                    .frame(width: 6.5, height: barHeight(Self.ratios[index]))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true) // GearText already says the gear
    }

    // A higher floor than the app's, so the easy gears stay bars and not dots at this size.
    private func barHeight(_ ratio: Double) -> CGFloat {
        let progress = (ratio - Self.ratios[0]) / (Self.ratios[Self.ratios.count - 1] - Self.ratios[0])
        return height * (0.3 + 0.7 * progress)
    }
}

extension View {
    /// Dims an activity the app stopped updating, so a frozen gear doesn't pass for the current one.
    func dimmed(whenStale isStale: Bool) -> some View {
        opacity(isStale ? 0.4 : 1)
    }
}
