import SwiftUI

/// The one screen you look at while riding.
struct RideView: View {
    @Bindable var model: RideModel
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 0) {
            DeviceBar(connections: model.connections) { showsSettings = true }
            Spacer(minLength: 12)
            GearReadout(gear: model.gearbox.gear)
            GearRamp(gear: model.gearbox.gear, ratios: model.gearProfile.ratios, select: model.select(gear:))
                .padding(.top, 24)
            Spacer(minLength: 12)
            MetricsView(power: model.power, cadence: model.cadence)
                .padding(.bottom, 24)
            ShiftButtons(shift: model.shift(by:))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.snappy(duration: 0.25), value: model.gearbox.gear)
        .sheet(isPresented: $showsSettings) { SettingsView(model: model) }
    }
}

#Preview {
    RideView(model: .demo())
        .tint(.zwiftInk)
}
