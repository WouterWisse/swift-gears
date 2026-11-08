import GearsCore
import SwiftUI

/// The three devices, what to do next to connect them, and the way into settings.
struct DeviceBar: View {
    let connections: [DeviceRole: ConnectionState]
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 18) {
                DeviceLabel(image: "trainer", name: "Trainer", state: connections[.trainer])
                DeviceLabel(image: "hood", name: "Left", state: connections[.leftShifter])
                DeviceLabel(image: "hood", mirrored: true, name: "Right", state: connections[.rightShifter])
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .tint(.primary)
                .accessibilityLabel("Settings")
            }
            Text(hint ?? " ") // a blank line keeps the layout still once everything connects
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(hint == nil)
        }
    }

    /// What the rider should do next, problems first.
    private var hint: String? {
        let pending = DeviceRole.allCases
            .compactMap { role in connections[role].map { (role, $0) } }
            .filter { !$0.1.isConnected }
        guard let (role, state) = pending.first(where: { $0.1.isProblem }) ?? pending.first else { return nil }
        switch state {
        case .bluetoothOff: return "Turn on Bluetooth and allow SwiftGears to use it in Settings."
        case .noZwiftService: return "Your trainer has no Zwift shifting yet. Update it in the Wahoo app."
        case .locked: return "The Ride is locked. Open Zwift once to unlock it, then come back."
        case .searching: return role == .trainer ? "Pedal to wake your trainer." : "Press a button on each hood to wake the Ride."
        case .connecting, .reconnecting: return role == .trainer ? "Connecting to your trainer…" : "Connecting to the Ride…"
        case .connected: return nil
        }
    }
}

struct DeviceLabel: View {
    let image: String
    var mirrored = false
    let name: String
    let state: ConnectionState?
    @ScaledMetric(relativeTo: .subheadline) private var iconSize = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Nil is before Bluetooth has reported in, which is also still working.
    private var isWorking: Bool { state?.isWorking ?? true }

    var body: some View {
        HStack(spacing: 6) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(x: mirrored ? -1 : 1)
            Text(name)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(state?.isConnected == true ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
        .phaseAnimator(isWorking && !reduceMotion ? [1, 0.3] : [1]) { content, opacity in
            content.opacity(opacity)
        } animation: { _ in
            .easeInOut(duration: 0.8)
        }
        .overlay(alignment: .topLeading) {
            if state?.needsAction == true {
                Circle().fill(.red).frame(width: 8, height: 8).offset(x: -3, y: -3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(state?.isConnected == true ? "Connected" : "Not connected")
    }
}
