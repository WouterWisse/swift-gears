import GearsCore
import Testing

struct GearboxTests {
    @Test func startsInTheMiddleGear() {
        let gearbox = Gearbox()
        #expect(gearbox.gear == 12)
        #expect(gearbox.ratio == 2.40)
    }

    @Test func shiftsWithinTheRange() {
        var gearbox = Gearbox(gear: 23)
        let up = gearbox.shift(by: 1)
        let pastTop = gearbox.shift(by: 1)
        #expect(up)
        #expect(!pastTop)
        #expect(gearbox.gear == 24)
    }

    @Test func selectClampsAndReportsChanges() {
        var gearbox = Gearbox()
        let toBottom = gearbox.select(-5)
        #expect(toBottom)
        #expect(gearbox.gear == 1)
        let same = gearbox.select(1)
        #expect(!same)
        gearbox.select(99)
        #expect(gearbox.gear == Gearbox.count)
    }
}
