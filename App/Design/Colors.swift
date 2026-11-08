import SwiftUI

extension Color {
    /// Zwift's logo orange, for graphics and large type.
    static let zwift = Color(red: 242 / 255, green: 84 / 255, blue: 27 / 255)

    /// The orange for small text and controls: darker in light mode to keep 4.5:1 contrast on white.
    static let zwiftInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 242 / 255, green: 84 / 255, blue: 27 / 255, alpha: 1)
            : UIColor(red: 194 / 255, green: 64 / 255, blue: 15 / 255, alpha: 1)
    })
}
