/// The virtual gears: Zwift's 24 chainring:cog ratios and the one you are in.
public struct Gearbox: Equatable, Sendable {
    public static let ratios: [Double] = [
        0.75, 0.87, 0.99, 1.11, 1.23, 1.38, 1.53, 1.68, 1.86, 2.04, 2.22, 2.40,
        2.61, 2.82, 3.03, 3.24, 3.49, 3.74, 3.99, 4.24, 4.54, 4.84, 5.14, 5.49,
    ]
    public static var count: Int { ratios.count }

    /// 1 is the easiest gear, `count` the hardest.
    public private(set) var gear: Int

    /// Starts in gear 12, which is about the 34x14 a rider has on the Zwift Cog.
    public init(gear: Int = 12) {
        self.gear = min(max(gear, 1), Self.count)
    }

    public var ratio: Double { Self.ratios[gear - 1] }

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
