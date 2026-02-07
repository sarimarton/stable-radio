import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        Form {
            Section(header: Text("About")) {
                HStack {
                    Text("Version:")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Protocol:")
                    Spacer()
                    Text("StableRadio v1")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Help")) {
                Text("To capture system audio:")
                    .font(.headline)

                Text("""
                1. Install BlackHole (https://github.com/ExistentialAudio/BlackHole)
                2. Open Audio MIDI Setup
                3. Create a Multi-Output Device
                4. Check both your speakers and BlackHole
                5. In StableRadio, select BlackHole as input
                """)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }
}

#Preview {
    SettingsView()
        .environmentObject(MainViewModel())
}
