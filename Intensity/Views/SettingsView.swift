import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("saveToHealth") private var saveToHealth = false
    @State private var healthMessage: String?

    private let health = HealthService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $saveToHealth) {
                        Label {
                            Text("Save workouts to Apple Health")
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                    }
                    .tint(.pink)
                    .disabled(!health.isAvailable)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text(healthMessage ?? "Finished workouts are saved as High Intensity Interval Training, with estimated active calories. If you wear an Apple Watch, your heart rate during the workout appears in the summary and history.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .onChange(of: saveToHealth) { _, enabled in
                guard enabled else { return }
                Task { await connectHealth() }
            }
        }
    }

    private func connectHealth() async {
        healthMessage = nil
        try? await health.requestAuthorization()
        // The permission sheet only appears once; after that, access is changed in the Health app.
        if !health.canSaveWorkouts {
            saveToHealth = false
            healthMessage = "Intensity isn't allowed to save workouts. Turn it on in Settings → Privacy & Security → Health → Intensity, then switch this on again."
        }
    }
}
