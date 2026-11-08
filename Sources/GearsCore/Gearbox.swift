/// Which 24 chainring:cog ratios the gears use.
public enum GearProfile: String, CaseIterable, Sendable {
    /// Zwift's own: from very light to very hard, in big steps.
    case standard
    /// 1.10 to 3.30 in even steps of about 5%: no gears too light or too hard for a flat road.
    case balanced

    public var ratios: [Double] {
        switch self {
        case .standard: [
            0.75, 0.87, 0.99, 1.11, 1.23, 1.38, 1.53, 1.68, 1.86, 2.04, 2.22, 2.40,
            2.61, 2.82, 3.03, 3.24, 3.49, 3.74, 3.99, 4.24, 4.54, 4.84, 5.14, 5.49,
        ]
        case .balanced: [
            1.10, 1.15, 1.21, 1.27, 1.33, 1.40, 1.47, 1.54, 1.61, 1.69, 1.77, 1.86,
            1.95, 2.05, 2.15, 2.25, 2.36, 2.48, 2.60, 2.73, 2.86, 3.00, 3.15, 3.30,
        ]
        }
    }
}

/// The virtual gears: a profile's ratios and the one you are in.
public struct Gearbox: Equatable, Sendable {
    /// Every profile has this many gears.
    public static let count = 24

    /// 1 is the easiest gear, `count` the hardest.
    public private(set) var gear: Int
    /// Changing it keeps the gear number.
    public var profile: GearProfile

    /// Starts in gear 12, which on the standard profile is about the 34x14 a rider has on the Zwift Cog.
    public init(gear: Int = 12, profile: GearProfile = .standard) {
        self.gear = min(max(gear, 1), Self.count)
        self.profile = profile
    }

    public var ratio: Double { profile.ratios[gear - 1] }

    /// Moves to a gear, staying within the range. Returns whether the gear changed.
    @discardableResult
    public mutating func select(_ newGear: Int) -> Bool {
        let clamped = min(max(newGear, 1), Self.count)
        guard clamped != gear else { return false }
        gear = clamped
        return true
    }

    @discardableResult
    public mutating func shift(by delta: Int) -> Bool {
        select(gear + delta)
    }
}
