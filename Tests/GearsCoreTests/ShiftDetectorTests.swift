@testable import GearsCore
import Testing

struct ShiftDetectorTests {
    private let released: UInt64 = 0xFFFF_FFFF

    @Test func buttonPressShiftsOncePerPress() {
        var detector = ShiftDetector()
        #expect(detector.shifts(for: ride(buttons: released)) == [])
        #expect(detector.shifts(for: ride(buttons: released & ~0x0100)) == [-1])
        #expect(detector.shifts(for: ride(buttons: released & ~0x0100)) == [])
        #expect(detector.shifts(for: ride(buttons: released)) == [])
        #expect(detector.shifts(for: ride(buttons: released & ~0x2000)) == [1])
    }

    @Test func otherButtonsDoNotShift() {
        var detector = ShiftDetector()
        #expect(detector.shifts(for: ride(buttons: released & ~0x0010)) == []) // A
        #expect(detector.shifts(for: ride(buttons: released & ~0x0001)) == []) // left on the d-pad
    }

    @Test func analogPaddleUsesHysteresis() {
        var detector = ShiftDetector()
        #expect(detector.shifts(for: ride(paddle: (1, 30))) == [1])
        #expect(detector.shifts(for: ride(paddle: (1, 22))) == [])
        #expect(detector.shifts(for: ride(paddle: (1, 10))) == [])
        #expect(detector.shifts(for: ride(paddle: (1, 24))) == [])
        #expect(detector.shifts(for: ride(paddle: (0, -40))) == [-1])
    }

    @Test func ignoresOtherMessages() {
        var detector = ShiftDetector()
        #expect(detector.shifts(for: [0x19, 0x08, 0x50]) == []) // battery
        #expect(detector.shifts(for: [0x23, 0x08]) == []) // truncated
    }

    private func ride(buttons: UInt64 = 0xFFFF_FFFF, paddle: (location: UInt64, value: Int64)? = nil) -> [UInt8] {
        var bytes: [UInt8] = [0x23] + Protobuf.field(1, varint: buttons)
        if let paddle {
            let zigzag = UInt64(bitPattern: (paddle.value << 1) ^ (paddle.value >> 63))
            bytes += Protobuf.field(3, message: Protobuf.field(1, varint: paddle.location) + Protobuf.field(2, varint: zigzag))
        }
        return bytes
    }
}
