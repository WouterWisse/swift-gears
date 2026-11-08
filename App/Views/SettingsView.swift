import GearsCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: RideModel
    @Environment(\.dismiss) private var dismiss

    private static let sourceURL = URL(string: "https://github.com/WouterWisse/swift-gears")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $model.riderKg, in: 30...200) {
                        LabeledContent("Your weight", value: "\(Int(model.riderKg)) kg")
                    }
                } footer: {
                    Text("The trainer uses your weight to work out how heavy each gear feels.")
                }
                Section {
                    Picker("Gears", selection: $model.gearProfile) {
                        Text("Default").tag(GearProfile.standard)
                        Text("Balanced").tag(GearProfile.balanced)
                    }
                } footer: {
                    Text("Default uses Zwift's gears, from very light to very hard. Balanced leaves out the extremes and shifts in smaller steps.")
                }
                Section {
                    Toggle("Live Activity", isOn: $model.showsLiveActivity)
                } footer: {
                    Text("Shows your gear, watts and rpm on the Lock Screen and in the Dynamic Island while you ride.")
                }
                Section {
                    if model.isConnecting {
                        Button("Disconnect", role: .destructive) {
                            model.disconnect()
                            dismiss()
                        }
                    } else {
                        Button("Connect") { model.connect() }
                    }
                } footer: {
                    Text("Disconnect when you're done riding. It also ends the Live Activity.")
                }
                Section {
                    Link("Source code on GitHub", destination: Self.sourceURL)
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
