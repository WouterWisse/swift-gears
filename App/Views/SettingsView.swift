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
