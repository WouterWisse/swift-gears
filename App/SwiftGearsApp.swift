import SwiftUI

@main
struct SwiftGearsApp: App {
    @State private var model: RideModel = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo") {
            let model = RideModel.demo()
            if arguments.contains("-demo-loop") { model.playDemoLoop() }
            return model
        }
        #endif
        return RideModel()
    }()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RideView(model: model)
                .tint(.zwiftInk)
                // A ride screen: keep it on while the app is in front.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                .onChange(of: scenePhase, initial: true) {
                    if scenePhase == .active { model.startLiveActivity() }
                }
        }
    }
}
