import Foundation
import GearsCore
import Observation

/// Everything the ride screen shows, and the gear changes it asks for.
@Observable
final class RideModel {
    private(set) var gearbox = Gearbox()
    private(set) var connections: [DeviceRole: ConnectionState] = [:]
    private(set) var power: Int?
    private(set) var cadence: Int?
    var riderKg: Double {
        didSet {
            defaults.set(riderKg, forKey: Self.riderKgKey)
            sendGear()
        }
    }

    @ObservationIgnored private let central: ZwiftCentral?
    @ObservationIgnored private let defaults: UserDefaults

    private static let riderKgKey = "riderKg"
    // The trainer only needs a bike weight for its physics; on a flat road it barely matters.
    private static let bikeKg = 10.0

    /// Pass no central for a ride without Bluetooth, as in previews.
    init(central: ZwiftCentral? = ZwiftCentral(), defaults: UserDefaults = .standard) {
        self.central = central
        self.defaults = defaults
        riderKg = defaults.object(forKey: Self.riderKgKey) as? Double ?? 75

        central?.onStateChange = { [weak self] role, state in self?.connections[role] = state }
        central?.onTrainerReady = { [weak self] in self?.sendGear() }
        central?.onRidingData = { [weak self] data in
            self?.power = data?.power
            self?.cadence = data?.cadence
        }
        central?.onShift = { [weak self] delta in self?.shift(by: delta) }
        central?.start()
    }

    func shift(by delta: Int) {
        if gearbox.shift(by: delta) { sendGear() }
    }

    func select(gear: Int) {
        if gearbox.select(gear) { sendGear() }
    }

    private func sendGear() {
        central?.setGear(ratio: gearbox.ratio, bikeKg: Self.bikeKg, riderKg: riderKg)
    }
}

#if DEBUG
extension RideModel {
    /// A connected ride without Bluetooth, for previews and screenshots (launch with `-demo`).
    static func demo() -> RideModel {
        let model = RideModel(central: nil)
        model.gearbox.select(16)
        for role in DeviceRole.allCases { model.connections[role] = .connected }
        model.power = 212
        model.cadence = 88
        return model
    }
}
#endif
