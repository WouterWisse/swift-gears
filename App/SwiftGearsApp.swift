import SwiftUI

@main
struct SwiftGearsApp: App {
    @State private var model: RideModel = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return .demo() }
        #endif
        return RideModel()
    }()

    var body: some Scene {
        WindowGroup {
            RideView(model: model)
                .tint(.zwiftInk)
                // A ride screen: keep it on while the app is in front.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}
