import CoreBluetooth
import GearsCore
import Observation

/// Connects the KICKR CORE and both Zwift Ride halves, and turns shifter presses into virtual gears on the trainer.
@Observable
final class Bike: NSObject {
    enum Role: CaseIterable { case trainer, left, right }

    enum Link {
        case searching, connecting, connected, reconnecting, bluetoothOff, noZwiftService, locked

        var isConnected: Bool { self == .connected }
        var isProblem: Bool { [.bluetoothOff, .noZwiftService, .locked].contains(self) }
        /// A problem with this one device, as opposed to Bluetooth as a whole.
        var needsAction: Bool { [.noZwiftService, .locked].contains(self) }
    }

    private(set) var gear = 12
    private(set) var links: [Role: Link] = [:]
    private(set) var power: Int?
    private(set) var cadence: Int?
    var riderKg = UserDefaults.standard.object(forKey: "riderKg") as? Double ?? 75 {
        didSet {
            UserDefaults.standard.set(riderKg, forKey: "riderKg")
            sendGear()
        }
    }

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var peripherals: [Role: CBPeripheral] = [:]
    @ObservationIgnored private var controlPoints: [Role: CBCharacteristic] = [:]
    @ObservationIgnored private var detectors: [Role: ShiftDetector] = [:]
    @ObservationIgnored private var trainerReady = false

    // The Ride moved to the short FC82 service in a 2025 firmware; trainers keep the long one.
    private static let zwiftServices = [CBUUID(string: "00000001-19CA-4651-86E5-FA29DCDD09D1"), CBUUID(string: "FC82")]
    private static let controlPoint = CBUUID(string: "00000003-19CA-4651-86E5-FA29DCDD09D1")
    private static let notifying = [CBUUID(string: "00000002-19CA-4651-86E5-FA29DCDD09D1"), CBUUID(string: "00000004-19CA-4651-86E5-FA29DCDD09D1")]
    private static let bikeKg = 10.0

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func shift(_ delta: Int) {
        select(gear: gear + delta)
    }

    func select(gear newGear: Int) {
        let clamped = min(max(newGear, 1), Zwift.gearRatios.count)
        guard clamped != gear else { return }
        gear = clamped
        sendGear()
    }

    private func sendGear() {
        guard trainerReady else { return }
        write(Zwift.gearCommand(ratio: Zwift.gearRatios[gear - 1], bikeKg: Self.bikeKg, riderKg: riderKg), to: .trainer)
    }

    private func write(_ bytes: [UInt8], to role: Role) {
        guard let peripheral = peripherals[role], let characteristic = controlPoints[role] else { return }
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(Data(bytes), for: characteristic, type: type)
    }

    private func role(of peripheral: CBPeripheral) -> Role? {
        peripherals.first { $0.value === peripheral }?.key
    }

    private static func role(advertisement: [String: Any], name: String?) -> Role? {
        // Zwift devices advertise manufacturer 0x094A followed by a device type byte.
        if let data = advertisement[CBAdvertisementDataManufacturerDataKey] as? Data, data.count >= 3 {
            let bytes = [UInt8](data)
            if bytes[0] == 0x4A, bytes[1] == 0x09 {
                switch bytes[2] {
                case 0x07: return .right
                case 0x08: return .left
                default: break
                }
            }
        }
        let name = advertisement[CBAdvertisementDataLocalNameKey] as? String ?? name ?? ""
        return name.hasPrefix("KICKR") ? .trainer : nil
    }
}

extension Bike: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            for role in Role.allCases where controlPoints[role] == nil { links[role] = .bluetoothOff }
            return
        }
        for role in Role.allCases where peripherals[role] == nil { links[role] = .searching }
        central.scanForPeripherals(withServices: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        guard let role = Self.role(advertisement: advertisementData, name: peripheral.name), peripherals[role] == nil else { return }
        peripherals[role] = peripheral
        peripheral.delegate = self
        links[role] = .connecting
        central.connect(peripheral)
        if peripherals.count == Role.allCases.count { central.stopScan() }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(Self.zwiftServices)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        reconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reconnect(peripheral)
    }

    private func reconnect(_ peripheral: CBPeripheral) {
        guard let role = role(of: peripheral) else { return }
        controlPoints[role] = nil
        detectors[role] = nil
        if role == .trainer {
            trainerReady = false
            power = nil
            cadence = nil
        }
        links[role] = .reconnecting
        central.connect(peripheral) // iOS keeps this pending until the device is back, also in the background.
    }
}

extension Bike: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let role = role(of: peripheral) else { return }
        guard let service = peripheral.services?.first(where: { Self.zwiftServices.contains($0.uuid) }) else {
            links[role] = role == .trainer ? .noZwiftService : .locked
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
            links[role] = .connected
            if role == .trainer {
                trainerReady = true
                write(Zwift.flatRoad, to: .trainer)
                sendGear()
            }
        } else if role == .trainer {
            if let data = Zwift.ridingData(bytes) {
                power = data.power
                cadence = data.cadence
            }
        } else {
            for delta in detectors[role, default: ShiftDetector()].shifts(for: bytes) { shift(delta) }
        }
    }
}
