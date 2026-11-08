import ActivityKit

/// The ride on the Lock Screen and in the Dynamic Island. Built into both the app and the widget extension.
struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var gear: Int
        var gearCount: Int
        var power: Int?
        var cadence: Int?
    }
}
