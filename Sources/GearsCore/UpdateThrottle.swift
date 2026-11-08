/// Decides when a changed value goes out to a display that should not be flooded, like a Live Activity:
/// an urgent change at once, any other change at most once per `interval`, the latest one winning.
public struct UpdateThrottle<Value: Equatable & Sendable>: Sendable {
    public enum Decision: Equatable, Sendable {
        case none
        case send(Value)
        /// Call `flush(at:)` at this instant to send the latest change.
        case wait(until: ContinuousClock.Instant)
    }

    public let interval: Duration
    /// An unchanged value goes out again this long after the last send, to show it is still current.
    public let refresh: Duration

    private var last: (value: Value, at: ContinuousClock.Instant)?
    private var pending: Value?

    public init(interval: Duration, refresh: Duration) {
        self.interval = interval
        self.refresh = refresh
    }

    public mutating func submit(_ value: Value, urgent: Bool, at now: ContinuousClock.Instant) -> Decision {
        guard let last else { return send(value, at: now) }
        if value == last.value {
            pending = nil
            return now - last.at >= refresh ? send(value, at: now) : .none
        }
        if urgent || now - last.at >= interval { return send(value, at: now) }
        defer { pending = value }
        return pending == nil ? .wait(until: last.at + interval) : .none
    }

    /// The latest change that waited, if it is still unsent.
    public mutating func flush(at now: ContinuousClock.Instant) -> Value? {
        guard let pending, case .send(let value) = send(pending, at: now) else { return nil }
        return value
    }

    private mutating func send(_ value: Value, at now: ContinuousClock.Instant) -> Decision {
        last = (value, now)
        pending = nil
        return .send(value)
    }
}
