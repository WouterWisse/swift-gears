import GearsCore
import Testing

struct DeviceRoleTests {
    @Test func recognisesTheRideByItsLeftHalf() {
        #expect(DeviceRole(manufacturerData: [0x4A, 0x09, 0x08, 0x12], name: nil) == .ride)
    }

    @Test func skipsTheRightHalfBecauseTheLeftReportsBoth() {
        #expect(DeviceRole(manufacturerData: [0x4A, 0x09, 0x07, 0x34], name: "Zwift Ride") == nil)
    }

    @Test func recognisesTheTrainerByName() {
        #expect(DeviceRole(manufacturerData: nil, name: "KICKR CORE 5D2A") == .trainer)
    }

    @Test func ignoresEverythingElse() {
        #expect(DeviceRole(manufacturerData: [0x4A, 0x09, 0x09], name: nil) == nil) // Zwift Click
        #expect(DeviceRole(manufacturerData: [0x4C, 0x00, 0x08], name: "AirPods") == nil)
        #expect(DeviceRole(manufacturerData: [0x4A], name: nil) == nil)
    }
}
