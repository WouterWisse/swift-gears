import ActivityKit
import Foundation
import GearsCore
import os

/// Owns the ride's Live Activity: starts it while the app is in front and keeps it current from the model,
/// also in the background. Only the rider ends it (`stop()`): iOS can kill the app without warning, so a stale
/// date marks a frozen one and the next launch ends it.
final class RideActivityController {
    typealias State = RideActivityAttributes.ContentState

    private var activity: Activity<RideActivityAttributes>?
    private var isStarting = false
    // False once the rider turned it off, so a start still in flight doesn't bring it back.
    private var isWanted = false
    private var throttle = UpdateThrottle<State>(interval: .seconds(1), refresh: .seconds(60))
    private var flush: Task<Void, Never>?
    // One update at a time, so a quick run of shifts can't arrive out of order. While one is out, only the
    // newest state waits: when iOS is slow to take updates in the background, the display skips ahead
    // instead of working through a growing queue of old ones.
    private var waiting: State?
    private var isSending = false

    private var isRunning: Bool {
        activity?.activityState == .active || activity?.activityState == .stale
    }

    /// Call when the app becomes active: iOS only lets an app start a Live Activity while it is in front.
    func start(with state: State) {
        guard !isRunning, !isStarting, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        isStarting = true
        isWanted = true
        let leftovers = Activity<RideActivityAttributes>.activities
        Task { @MainActor in
            // An earlier run's activity can't be taken over: iOS stops showing it once its app has died.
            // End those first and only then ask for a new one, or iOS may hide the new one too.
            for leftover in leftovers { await leftover.end(nil, dismissalPolicy: .immediate) }
            defer { isStarting = false }
            guard isWanted else { return }
            do {
                activity = try Activity.request(attributes: RideActivityAttributes(), content: Self.content(state))
                _ = throttle.submit(state, urgent: true, at: .now) // the request already shows it
            } catch {
                // Optional: the ride goes on without it, but say why.
                Self.log.error("Could not start the Live Activity: \(error, privacy: .public)")
            }
        }
    }

    /// Ends it now and keeps it off until the next `start`.
    func stop() {
        isWanted = false
        flush?.cancel()
        waiting = nil
        activity = nil
        // Only the ones running now: switching back on right away must not end the new one.
        let running = Activity<RideActivityAttributes>.activities
        Task { @MainActor in
            for activity in running { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Shows a new state: a gear change (`urgent`) at once, power and cadence at most about once a second.
    func update(_ state: State, urgent: Bool) {
        guard isRunning else { return }
        switch throttle.submit(state, urgent: urgent, at: .now) {
        case .none:
            break
        case .send(let state):
            send(state)
        case .wait(let deadline):
            flush?.cancel()
            flush = Task { @MainActor [weak self] in
                try? await Task.sleep(until: deadline, clock: .continuous)
                guard !Task.isCancelled, let self, let state = throttle.flush(at: .now) else { return }
                send(state)
            }
        }
    }

    private func send(_ state: State) {
        waiting = state
        guard !isSending else { return }
        isSending = true
        Task { @MainActor in
            while let state = waiting, let activity {
                waiting = nil
                let took = await ContinuousClock().measure { await activity.update(Self.content(state)) }
                if took > .seconds(1) { Self.log.notice("A Live Activity update took \(took, privacy: .public)") }
            }
            waiting = nil
            isSending = false
        }
    }

    private static let log = Logger(subsystem: "com.wouterwisse.swiftgears", category: "LiveActivity")

    private static func content(_ state: State) -> ActivityContent<State> {
        // The throttle resends at least every minute while data comes in, so this only passes once the app stops.
        ActivityContent(state: state, staleDate: .now + 120)
    }
}
