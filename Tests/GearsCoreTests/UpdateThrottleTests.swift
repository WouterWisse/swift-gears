import GearsCore
import Testing

struct UpdateThrottleTests {
    private var throttle = UpdateThrottle<Int>(interval: .seconds(1), refresh: .seconds(60))
    private let start = ContinuousClock.now

    private func at(_ seconds: Double) -> ContinuousClock.Instant {
        start + .seconds(seconds)
    }

    @Test mutating func sendsTheFirstValueAtOnce() {
        #expect(throttle.submit(1, urgent: false, at: at(0)) == .send(1))
    }

    @Test mutating func resendsAnUnchangedValueOnlyAfterTheRefresh() {
        _ = throttle.submit(1, urgent: false, at: at(0))
        #expect(throttle.submit(1, urgent: true, at: at(30)) == .none)
        #expect(throttle.submit(1, urgent: false, at: at(60)) == .send(1))
    }

    @Test mutating func sendsAChangeAtOnceAfterAQuietInterval() {
        _ = throttle.submit(1, urgent: false, at: at(0))
        #expect(throttle.submit(2, urgent: false, at: at(1.5)) == .send(2))
    }

    @Test mutating func coalescesChangesWithinTheInterval() {
        _ = throttle.submit(1, urgent: false, at: at(0))
        #expect(throttle.submit(2, urgent: false, at: at(0.2)) == .wait(until: at(1)))
        #expect(throttle.submit(3, urgent: false, at: at(0.5)) == .none)
        #expect(throttle.flush(at: at(1)) == 3)
        #expect(throttle.flush(at: at(1)) == nil)
        #expect(throttle.submit(4, urgent: false, at: at(1.4)) == .wait(until: at(2)))
    }

    @Test mutating func sendsAnUrgentChangeAtOnceAndDropsTheWaitingOne() {
        _ = throttle.submit(1, urgent: false, at: at(0))
        _ = throttle.submit(2, urgent: false, at: at(0.2))
        #expect(throttle.submit(3, urgent: true, at: at(0.4)) == .send(3))
        #expect(throttle.flush(at: at(1)) == nil)
    }

    @Test mutating func dropsAWaitingChangeThatWasUndone() {
        _ = throttle.submit(1, urgent: false, at: at(0))
        _ = throttle.submit(2, urgent: false, at: at(0.2))
        #expect(throttle.submit(1, urgent: false, at: at(0.4)) == .none)
        #expect(throttle.flush(at: at(1)) == nil)
    }
}
