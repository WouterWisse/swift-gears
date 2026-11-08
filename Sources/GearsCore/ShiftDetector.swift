/// Turns Zwift Ride button notifications (opcode 0x23, RideKeyPadStatus) into gear shifts.
/// Like in Zwift, every left-hand shift control goes easier and every right-hand one harder.
public struct ShiftDetector: Sendable {
    static let leftShiftButtons: UInt64 = 0x0100 | 0x0200
    static let rightShiftButtons: UInt64 = 0x1000 | 0x2000
    // Analog paddles drift a little: press at 25, release under 20, so one push is one shift.
    static let paddlePress: Int64 = 25
    static let paddleRelease: Int64 = 20

    private var easierHeld = false
    private var harderHeld = false

    public init() {}

    /// Feeds one notification and returns each newly pressed shift: -1 easier, +1 harder.
    public mutating func shifts(for bytes: [UInt8]) -> [Int] {
        guard bytes.first == 0x23, let fields = Protobuf.parse(bytes.dropFirst()) else { return [] }
        // Active-low: a 0 bit is a pressed button. A missing map means nothing is pressed.
        let pressed = ~(fields.value(1) ?? .max)
        var paddles: [UInt64: Int64] = [:]
        for paddle in fields where paddle.number == 3 {
            guard let sub = Protobuf.parse(paddle.bytes) else { continue }
            let location = sub.value(1) ?? 0 // 0 left, 1 right
            paddles[location] = abs(Protobuf.signed(sub.value(2) ?? 0))
        }

        let easier = pressed & Self.leftShiftButtons != 0 || isPressed(paddles[0], held: easierHeld)
        let harder = pressed & Self.rightShiftButtons != 0 || isPressed(paddles[1], held: harderHeld)
        defer {
            easierHeld = easier
            harderHeld = harder
        }
        return (easier && !easierHeld ? [-1] : []) + (harder && !harderHeld ? [1] : [])
    }

    private func isPressed(_ paddle: Int64?, held: Bool) -> Bool {
        (paddle ?? 0) >= (held ? Self.paddleRelease : Self.paddlePress)
    }
}
