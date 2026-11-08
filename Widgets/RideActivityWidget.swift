import ActivityKit
import SwiftUI
import WidgetKit

/// The ride's Live Activity: gear, power and cadence on the Lock Screen and in the Dynamic Island.
@main
struct RideActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .dimmed(whenStale: context.isStale)
        } dynamicIsland: { context in
            let state = context.state
            let isStale = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GearText(state: state, size: 52)
                        .padding(.leading, 6)
                        .dimmed(whenStale: isStale)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        MetricText(value: state.power, unit: "W", name: "Power", size: 26)
                        MetricText(value: state.cadence, unit: "rpm", name: "Cadence", size: 26)
                    }
                    .padding(.trailing, 6)
                    .dimmed(whenStale: isStale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityGearRamp(gear: state.gear, height: 24)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                        .dimmed(whenStale: isStale)
                }
            } compactLeading: {
                GearText(state: state, size: 22, showsCount: false)
                    .foregroundStyle(Color.zwift)
                    .dimmed(whenStale: isStale)
            } compactTrailing: {
                MetricText(value: state.power, unit: "W", name: "Power", size: 22)
                    .dimmed(whenStale: isStale)
            } minimal: {
                GearText(state: state, size: 22, showsCount: false)
                    .foregroundStyle(Color.zwift)
                    .dimmed(whenStale: isStale)
            }
            .keylineTint(.zwift)
        }
    }
}

private struct LockScreenView: View {
    let state: RideActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                GearText(state: state, size: 64)
                Spacer(minLength: 0)
                MetricText(value: state.power, unit: "W", name: "Power", size: 30)
                MetricText(value: state.cadence, unit: "rpm", name: "Cadence", size: 30)
            }
            ActivityGearRamp(gear: state.gear, height: 30)
        }
        .padding(16)
    }
}

#Preview("Lock Screen", as: .content, using: RideActivityAttributes()) {
    RideActivityWidget()
} contentStates: {
    RideActivityAttributes.ContentState(gear: 16, gearCount: 24, power: 212, cadence: 88)
    RideActivityAttributes.ContentState(gear: 3, gearCount: 24, power: nil, cadence: nil)
}
