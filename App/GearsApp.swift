import GearsCore
import SwiftUI

@main
struct GearsApp: App {
    @State private var bike = Bike()

    var body: some Scene {
        WindowGroup {
            RideView(bike: bike)
                .tint(.zwiftInk)
                // A ride screen: keep it on while the app is in front.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

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

struct RideView: View {
    @Bindable var bike: Bike
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 0) {
            DeviceBar(links: bike.links) { showsSettings = true }
            Spacer(minLength: 12)
            GearReadout(gear: bike.gear)
            GearRamp(gear: bike.gear, select: bike.select(gear:))
                .padding(.top, 24)
            Spacer(minLength: 12)
            Metrics(power: bike.power, cadence: bike.cadence)
                .padding(.bottom, 24)
            ShiftButtons(shift: bike.shift)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.snappy(duration: 0.25), value: bike.gear)
        .sheet(isPresented: $showsSettings) { SettingsView(bike: bike) }
    }
}

// MARK: Devices

struct DeviceBar: View {
    let links: [Bike.Role: Bike.Link]
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 18) {
                DeviceLabel(image: "trainer", name: "Trainer", link: links[.trainer])
                DeviceLabel(image: "hood", name: "Left", link: links[.left])
                DeviceLabel(image: "hood", mirrored: true, name: "Right", link: links[.right])
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .tint(.primary)
                .accessibilityLabel("Settings")
            }
            Text(hint ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(hint == nil)
        }
    }

    /// What the rider should do next, problems first.
    private var hint: String? {
        let roles: [Bike.Role] = [.trainer, .left, .right]
        let pending = roles.compactMap { role in links[role].map { (role, $0) } }.filter { !$0.1.isConnected }
        guard let (role, link) = pending.first(where: { $0.1.isProblem }) ?? pending.first else { return nil }
        switch link {
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
    let link: Bike.Link?
    @ScaledMetric(relativeTo: .subheadline) private var iconSize = 20

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
        .foregroundStyle(link?.isConnected == true ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
        .overlay(alignment: .topLeading) {
            if link?.needsAction == true {
                Circle().fill(.red).frame(width: 8, height: 8).offset(x: -3, y: -3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(link?.isConnected == true ? "Connected" : "Not connected")
    }
}

// MARK: Gear

struct GearReadout: View {
    let gear: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(gear)")
                    .font(.system(size: 190, weight: .black).width(.compressed))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(gear)))
                Text("/\(Zwift.gearRatios.count)")
                    .font(.system(size: 36, weight: .bold).width(.compressed))
                    .foregroundStyle(.tertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            Text("Ratio \(Zwift.gearRatios[gear - 1], specifier: "%.2f")")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gear \(gear) of \(Zwift.gearRatios.count)")
    }
}

/// The 24 gears as bars as tall as their ratio. Drag across it to pick a gear.
struct GearRamp: View {
    let gear: Int
    let select: (Int) -> Void
    @State private var width: CGFloat = 1
    private let ratios = Zwift.gearRatios

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(ratios.indices, id: \.self) { index in
                Capsule()
                    .fill(index < gear ? Color.zwift : Color.primary.opacity(0.1))
                    .frame(height: 20 + 108 * (ratios[index] - ratios[0]) / (ratios[ratios.count - 1] - ratios[0]))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 128, alignment: .bottom)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            select(Int(drag.location.x / width * CGFloat(ratios.count)) + 1)
        })
        .accessibilityElement()
        .accessibilityLabel("Gears")
        .accessibilityValue("Gear \(gear) of \(ratios.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(gear + 1)
            case .decrement: select(gear - 1)
            @unknown default: break
            }
        }
    }
}

// MARK: Ride data and controls

struct Metrics: View {
    let power: Int?
    let cadence: Int?

    var body: some View {
        HStack {
            metric(power, unit: "W", name: "Power")
            metric(cadence, unit: "rpm", name: "Cadence")
        }
    }

    private func metric(_ value: Int?, unit: String, name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 48, weight: .bold).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(value == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            Text(unit)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? "No data")
    }
}

struct ShiftButtons: View {
    let shift: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            button("Easier", symbol: "minus", delta: -1)
            button("Harder", symbol: "plus", delta: 1)
        }
    }

    private func button(_ title: String, symbol: String, delta: Int) -> some View {
        Button { shift(delta) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .bold))
                    .frame(height: 34)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(ShiftButtonStyle())
    }
}

struct ShiftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(.secondarySystemFill)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: Settings

struct SettingsView: View {
    @Bindable var bike: Bike
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $bike.riderKg, in: 30...200) {
                        LabeledContent("Your weight", value: "\(Int(bike.riderKg)) kg")
                    }
                } footer: {
                    Text("The trainer uses your weight to work out how heavy each gear feels.")
                }
                Section {
                    Link("Source code on GitHub", destination: URL(string: "https://github.com/WouterWisse/swift-gears")!)
                } footer: {
                    Text("SwiftGears is not affiliated with Zwift or Wahoo.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
