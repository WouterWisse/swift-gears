import CoreBluetooth
import GearsCore

/// How far along a device is in connecting.
enum ConnectionState: Equatable {
    case searching, connecting, connected, reconnecting
    case bluetoothOff, noZwiftService, locked

    var isConnected: Bool { self == .connected }
    /// Still looking for or connecting to the device.
    var isWorking: Bool { [.searching, .connecting, .reconnecting].contains(self) }
    /// Needs the rider before it can connect.
    var isProblem: Bool { [.bluetoothOff, .noZwiftService, .locked].contains(self) }
    /// A problem with this one device, as opposed to Bluetooth as a whole.
    var needsAction: Bool { [.noZwiftService, .locked].contains(self) }
}

/// Finds the trainer and both Ride shifters, keeps them connected and speaks Zwift's protocol to them.
/// It reports what happens through its callbacks and keeps no ride state of its own.
final class ZwiftCentral: NSObject {
    var onStateChange: (DeviceRole, ConnectionState) -> Void = { _, _ in }
    /// The trainer accepts gears from now on.
    var onTrainerReady: () -> Void = {}
    /// Nil when the trainer drops out.
    var onRidingData: (Zwift.RidingData?) -> Void = { _ in }
    /// -1 easier, +1 harder.
    var onShift: (Int) -> Void = { _ in }

    private var central: CBCentralManager?
    private var peripherals: [DeviceRole: CBPeripheral] = [:]
    private var controlPoints: [DeviceRole: CBCharacteristic] = [:]
    private var detectors: [DeviceRole: ShiftDetector] = [:]
    private var trainerReady = false

    private static let services = Zwift.serviceUUIDs.map(CBUUID.init(string:))
    private static let controlPoint = CBUUID(string: Zwift.controlPointUUID)
    private static let notifying = Zwift.notifyingUUIDs.map(CBUUID.init(string:))

    func start() {
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func setGear(ratio: Double, bikeKg: Double, riderKg: Double) {
        guard trainerReady else { return }
        write(Zwift.gearCommand(ratio: ratio, bikeKg: bikeKg, riderKg: riderKg), to: .trainer)
    }

    private func write(_ bytes: [UInt8], to role: DeviceRole) {
        guard let peripheral = peripherals[role], let characteristic = controlPoints[role] else { return }
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(Data(bytes), for: characteristic, type: type)
    }

    private func role(of peripheral: CBPeripheral) -> DeviceRole? {
        peripherals.first { $0.value === peripheral }?.key
    }

    private func reconnect(_ peripheral: CBPeripheral) {
        guard let role = role(of: peripheral) else { return }
        controlPoints[role] = nil
        detectors[role] = nil
        if role == .trainer {
            trainerReady = false
            onRidingData(nil)
        }
        onStateChange(role, .reconnecting)
        central?.connect(peripheral) // iOS keeps this pending until the device is back, also in the background.
    }
}

extension ZwiftCentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            for role in DeviceRole.allCases where controlPoints[role] == nil { onStateChange(role, .bluetoothOff) }
            return
        }
        for role in DeviceRole.allCases where peripherals[role] == nil { onStateChange(role, .searching) }
        central.scanForPeripherals(withServices: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let manufacturerData = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data).map { [UInt8]($0) }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard let role = DeviceRole(manufacturerData: manufacturerData, name: name), peripherals[role] == nil else { return }
        peripherals[role] = peripheral
        peripheral.delegate = self
        onStateChange(role, .connecting)
        central.connect(peripheral)
        if peripherals.count == DeviceRole.allCases.count { central.stopScan() }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(Self.services)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        reconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reconnect(peripheral)
    }
}

extension ZwiftCentral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let role = role(of: peripheral) else { return }
        guard let service = peripheral.services?.first(where: { Self.services.contains($0.uuid) }) else {
            // A locked Ride V2 hides its Zwift service until it is unlocked in Zwift.
            onStateChange(role, role == .trainer ? .noZwiftService : .locked)
            return
        }
        peripheral.discoverCharacteristics([Self.controlPoint] + Self.notifying, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let role = role(of: peripheral) else { return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.controlPoint {
                controlPoints[role] = characteristic
            } else {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        write(Zwift.rideOn, to: role)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let role = role(of: peripheral), let value = characteristic.value else { return }
        let bytes = [UInt8](value)
        if bytes.starts(with: Zwift.rideOn) {
            onStateChange(role, .connected)
            if role == .trainer {
                trainerReady = true
                write(Zwift.flatRoad, to: .trainer)
                onTrainerReady()
            }
        } else if role == .trainer {
            if let data = Zwift.ridingData(bytes) { onRidingData(data) }
        } else {
            for delta in detectors[role, default: ShiftDetector()].shifts(for: bytes) { onShift(delta) }
        }
    }
}
