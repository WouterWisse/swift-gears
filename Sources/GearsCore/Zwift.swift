/// Zwift's Bluetooth protocol, as reverse engineered by Makinolo (makinolo.com), SHIFTR and BikeControl.
/// Every message is one opcode byte followed by a protobuf body.
public enum Zwift {
    /// Zwift's 24 virtual gears as chainring:cog ratios.
    public static let gearRatios: [Double] = [
        0.75, 0.87, 0.99, 1.11, 1.23, 1.38, 1.53, 1.68, 1.86, 2.04, 2.22, 2.40,
        2.61, 2.82, 3.03, 3.24, 3.49, 3.74, 3.99, 4.24, 4.54, 4.84, 5.14, 5.49,
    ]

    /// Handshake both the trainer and the Ride halves expect, and echo back.
    public static let rideOn: [UInt8] = Array("RideOn".utf8)

    /// HubCommand.Physical: the virtual gear plus the weights the trainer's physics use.
    public static func gearCommand(ratio: Double, bikeKg: Double, riderKg: Double) -> [UInt8] {
        hubCommand(field: 5, [varintField(2, ratio * 10_000), varintField(4, bikeKg * 100), varintField(5, riderKg * 100)])
    }

    /// HubCommand.Simulation: a flat road with the drag (CWa 0.51) and rolling resistance (Crr 0.004) Zwift always sends.
    public static let flatRoad: [UInt8] = hubCommand(field: 4, [varintField(2, 0), varintField(3, 5100), varintField(4, 400)])

    public struct RidingData: Equatable, Sendable {
        public let power: Int
        public let cadence: Int
    }

    /// HubRidingData (opcode 0x03), notified by the trainer about once a second.
    public static func ridingData(_ bytes: [UInt8]) -> RidingData? {
        guard bytes.first == 0x03, let fields = parse(bytes.dropFirst()) else { return nil }
        func value(_ number: Int) -> Int { Int(clamping: fields.first { $0.number == number }?.value ?? 0) }
        return RidingData(power: value(1), cadence: value(2))
    }

    // MARK: Protobuf

    struct Field {
        let number: Int
        let value: UInt64 // varint fields
        let bytes: ArraySlice<UInt8> // length-delimited fields
    }

    /// Nil when the bytes are not a well-formed protobuf message (they come from a radio, so never trust them).
    static func parse(_ bytes: ArraySlice<UInt8>) -> [Field]? {
        var index = bytes.startIndex
        var fields: [Field] = []
        while index < bytes.endIndex {
            guard let (key, next) = readVarint(bytes, at: index) else { return nil }
            index = next
            switch key & 7 {
            case 0:
                guard let (value, next) = readVarint(bytes, at: index) else { return nil }
                fields.append(Field(number: Int(key >> 3), value: value, bytes: []))
                index = next
            case 2:
                guard let (length, start) = readVarint(bytes, at: index), length <= UInt64(bytes.endIndex - start) else { return nil }
                let end = start + Int(length)
                fields.append(Field(number: Int(key >> 3), value: 0, bytes: bytes[start..<end]))
                index = end
            default:
                return nil
            }
        }
        return fields
    }

    static func readVarint(_ bytes: ArraySlice<UInt8>, at start: Int) -> (UInt64, Int)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var index = start
        while index < bytes.endIndex, shift < 64 {
            let byte = bytes[index]
            value |= UInt64(byte & 0x7F) << shift
            index += 1
            if byte & 0x80 == 0 { return (value, index) }
            shift += 7
        }
        return nil
    }

    static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var out: [UInt8] = []
        repeat {
            out.append(UInt8(value & 0x7F) | (value > 0x7F ? 0x80 : 0))
            value >>= 7
        } while value != 0
        return out
    }

    private static func varintField(_ number: Int, _ value: Double) -> [UInt8] {
        [UInt8(number << 3)] + varint(UInt64(value.rounded()))
    }

    private static func hubCommand(field: Int, _ parts: [[UInt8]]) -> [UInt8] {
        let body = parts.flatMap { $0 }
        return [0x04, UInt8(field << 3 | 2)] + varint(UInt64(body.count)) + body
    }
}

/// Turns Zwift Ride button notifications (opcode 0x23, RideKeyPadStatus) into gear shifts.
/// Like Zwift: every left-hand shift control goes easier, every right-hand one harder.
public struct ShiftDetector: Sendable {
    static let leftShiftButtons: UInt64 = 0x0100 | 0x0200
    static let rightShiftButtons: UInt64 = 0x1000 | 0x2000
    // Analog paddles drift a little; press at 25, release under 20 so one push is one shift.
    static let paddlePress: Int64 = 25
    static let paddleRelease: Int64 = 20

    private var easierHeld = false
    private var harderHeld = false

    public init() {}

    /// Feeds one notification; returns each newly pressed shift: -1 easier, +1 harder.
    public mutating func shifts(for bytes: [UInt8]) -> [Int] {
        guard bytes.first == 0x23, let fields = Zwift.parse(bytes.dropFirst()) else { return [] }
        // Active-low: a 0 bit is a pressed button. A missing map means nothing is pressed.
        let pressed = ~(fields.first { $0.number == 1 }?.value ?? .max)
        var paddles: [UInt64: Int64] = [:]
        for paddle in fields where paddle.number == 3 {
            guard let sub = Zwift.parse(paddle.bytes) else { continue }
            let location = sub.first { $0.number == 1 }?.value ?? 0 // 0 left, 1 right
            let raw = sub.first { $0.number == 2 }?.value ?? 0 // sint32, zigzag encoded
            paddles[location] = abs(Int64(bitPattern: raw >> 1) ^ -Int64(bitPattern: raw & 1))
        }

        var shifts: [Int] = []
        let easier = pressed & Self.leftShiftButtons != 0 || paddles[0, default: 0] >= (easierHeld ? Self.paddleRelease : Self.paddlePress)
        let harder = pressed & Self.rightShiftButtons != 0 || paddles[1, default: 0] >= (harderHeld ? Self.paddleRelease : Self.paddlePress)
        if easier && !easierHeld { shifts.append(-1) }
        if harder && !harderHeld { shifts.append(1) }
        easierHeld = easier
        harderHeld = harder
        return shifts
    }
}
