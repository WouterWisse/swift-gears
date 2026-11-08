@testable import GearsCore
import Testing

struct ZwiftTests {
    @Test func gearCommandMatchesCapturedZwiftMessage() {
        // Makinolo's capture of Zwift talking to a KICKR CORE: gear 0, bike 6.41 kg, rider 76.2 kg.
        #expect(Zwift.gearCommand(ratio: 0, bikeKg: 6.41, riderKg: 76.2) == [0x04, 0x2A, 0x08, 0x10, 0x00, 0x20, 0x81, 0x05, 0x28, 0xC4, 0x3B])
    }

    @Test func gearCommandEncodesRatioTimesTenThousand() {
        let command = Zwift.gearCommand(ratio: 2.40, bikeKg: 10, riderKg: 75)
        let physical = Protobuf.parse(command.dropFirst())!.first!
        #expect(physical.number == 5)
        #expect(Protobuf.parse(physical.bytes)!.map(\.value) == [24_000, 1_000, 7_500])
    }

    @Test func flatRoadUsesZwiftsDragAndRolling() {
        #expect(Zwift.flatRoad == [0x04, 0x22, 0x08, 0x10, 0x00, 0x18, 0xEC, 0x27, 0x20, 0x90, 0x03])
    }

    @Test func decodesTrainerRidingData() {
        let captured: [UInt8] = [0x03, 0x08, 0xBE, 0x01, 0x10, 0x50, 0x18, 0xBD, 0x06, 0x20, 0x00, 0x28, 0xE2, 0xBA, 0x01, 0x30, 0x8B, 0xEB, 0x01]
        #expect(Zwift.ridingData(captured) == .init(power: 190, cadence: 80))
    }

    @Test func rejectsMalformedRidingData() {
        #expect(Zwift.ridingData([0x03, 0x08]) == nil) // truncated varint
        #expect(Zwift.ridingData([0x03, 0x0A, 0xFF, 0x01]) == nil) // length past the end
        #expect(Zwift.ridingData([0x23, 0x08, 0x01]) == nil) // not riding data
    }
}
