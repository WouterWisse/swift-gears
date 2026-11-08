import GearsCore
import SwiftUI

/// The current gear, big enough to read from the stand.
struct GearReadout: View {
    let gear: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(gear)")
                .font(.system(size: 190, weight: .black).width(.compressed))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(gear)))
            Text("/ \(Gearbox.count)")
                .font(.system(size: 36, weight: .bold).width(.compressed))
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gear \(gear) of \(Gearbox.count)")
    }
}

/// The 24 gears as bars as tall as their ratio, orange up to yours. Drag across it to pick a gear.
struct GearRamp: View {
    let gear: Int
    let ratios: [Double]
    let select: (Int) -> Void
    @State private var width: CGFloat = 1

    private static let minBarHeight: CGFloat = 20
    private static let maxBarHeight: CGFloat = 128

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(ratios.indices, id: \.self) { index in
                Capsule()
                    .fill(index < gear ? Color.zwift : Color.primary.opacity(0.1))
                    .frame(height: barHeight(ratios[index]))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Self.maxBarHeight, alignment: .bottom)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            select(Int(drag.location.x / width * CGFloat(Gearbox.count)) + 1)
        })
        .accessibilityElement()
        .accessibilityLabel("Gears")
        .accessibilityValue("Gear \(gear) of \(Gearbox.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(gear + 1)
            case .decrement: select(gear - 1)
            @unknown default: break
            }
        }
    }

    private func barHeight(_ ratio: Double) -> CGFloat {
        let progress = (ratio - ratios[0]) / (ratios[ratios.count - 1] - ratios[0])
        return Self.minBarHeight + (Self.maxBarHeight - Self.minBarHeight) * progress
    }
}
