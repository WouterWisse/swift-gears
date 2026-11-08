/// Zwift's Bluetooth protocol, as reverse engineered by Makinolo (makinolo.com), SHIFTR and BikeControl.
/// The trainer and the Ride share it: every message is one opcode byte followed by a protobuf body.
public enum Zwift {
    /// The Zwift service. The Ride moved to the short FC82 one in a 2025 firmware; trainers keep the long one.
    public static let serviceUUIDs = ["00000001-19CA-4651-86E5-FA29DCDD09D1", "FC82"]
    /// Write commands here.
    public static let controlPointUUID = "00000003-19CA-4651-86E5-FA29DCDD09D1"
    /// Subscribe to these: measurements (notify) and command responses (indicate).
    public static let notifyingUUIDs = ["00000002-19CA-4651-86E5-FA29DCDD09D1", "00000004-19CA-4651-86E5-FA29DCDD09D1"]

    /// The handshake. Devices answer it with a message that starts with the same bytes.
    public static let rideOn: [UInt8] = Array("RideOn".utf8)

    /// HubCommand.Physical: the virtual gear plus the weights the trainer's physics use.
    public static func gearCommand(ratio: Double, bikeKg: Double, riderKg: Double) -> [UInt8] {
        hubCommand(field: 5, [
            Protobuf.field(2, varint: scaled(ratio, by: 10_000)),
            Protobuf.field(4, varint: scaled(bikeKg, by: 100)),
            Protobuf.field(5, varint: scaled(riderKg, by: 100)),
        ])
    }

    /// HubCommand.Simulation: a flat road with the drag (CWa 0.51) and rolling resistance (Crr 0.004) Zwift always sends.
    public static let flatRoad: [UInt8] = hubCommand(field: 4, [
        Protobuf.field(2, varint: 0),
        Protobuf.field(3, varint: 5100),
        Protobuf.field(4, varint: 400),
    ])

    public struct RidingData: Equatable, Sendable {
        public let power: Int
        public let cadence: Int

        public init(power: Int, cadence: Int) {
            self.power = power
            self.cadence = cadence
        }
    }

    /// HubRidingData (opcode 0x03), which the trainer notifies about once a second.
    public static func ridingData(_ bytes: [UInt8]) -> RidingData? {
        guard bytes.first == 0x03, let fields = Protobuf.parse(bytes.dropFirst()) else { return nil }
        return RidingData(
            power: Int(clamping: fields.value(1) ?? 0),
            cadence: Int(clamping: fields.value(2) ?? 0)
        )
    }

    private static func hubCommand(field: Int, _ parts: [[UInt8]]) -> [UInt8] {
        [0x04] + Protobuf.field(field, message: parts.flatMap { $0 })
    }

    private static func scaled(_ value: Double, by factor: Double) -> UInt64 {
        UInt64(max(0, (value * factor).rounded()))
    }
}
