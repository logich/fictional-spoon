import AVFoundation
import SwiftUI

/// Landing screen for configuring arena, horse, and test before starting a ride.
struct HomeView: View {
    @State private var arenaSize: ArenaSize = .standard
    @State private var horseName: String = ""
    @State private var selectedTest: DressageTest? = SampleTests.trainingLevel1
    @State private var calibration: BeaconCalibration = .uncalibrated
    @State private var navigateToRide = false
    @State private var navigateToCalibration = false
    @State private var voiceRefreshToken = UUID()  // forces voice label to update after picker dismisses

    private var voiceLabel: String {
        _ = voiceRefreshToken
        if let id = VoicePreference.savedIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return "\(voice.name) (\(voice.quality.label))"
        }
        return "Automatic"
    }

    private var configuration: ArenaConfiguration {
        ArenaConfiguration(
            beaconUUID: ArenaConfiguration.prototype.beaconUUID,
            arenaSize: arenaSize,
            beaconMappings: ArenaConfiguration.prototype.beaconMappings
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Arena setup
                Section {
                    Picker("Arena Size", selection: $arenaSize) {
                        Text("Small (20\u{00D7}40m)").tag(ArenaSize.small)
                        Text("Standard (20\u{00D7}60m)").tag(ArenaSize.standard)
                    }
                } header: {
                    Text("Arena")
                } footer: {
                    Text("Using \(configuration.beaconMappings.count) beacons at \(configuration.beaconLetters.map(\.rawValue).sorted().joined(separator: ", "))")
                }

                // Calibration
                Section {
                    NavigationLink {
                        CalibrationView(configuration: configuration) { result in
                            calibration = result
                        }
                    } label: {
                        HStack {
                            Text("Calibrate Beacons")
                            Spacer()
                            if calibration.readings.isEmpty {
                                Text("Not calibrated")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(calibration.readings.count) beacons")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Stand 1m from each beacon to measure signal strength. Improves position accuracy.")
                }

                // Horse
                Section("Horse") {
                    TextField("Horse name", text: $horseName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                // Audio
                Section("Audio") {
                    NavigationLink {
                        VoicePickerView()
                            .onDisappear { voiceRefreshToken = UUID() }
                    } label: {
                        HStack {
                            Text("Caller Voice")
                            Spacer()
                            Text(voiceLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Test selection
                Section {
                    NavigationLink {
                        TestSelectionView(selectedTest: $selectedTest, arenaSize: arenaSize)
                    } label: {
                        HStack {
                            Text("Test")
                            Spacer()
                            Text(selectedTest?.name ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if let test = selectedTest {
                        Text("\(test.movements.count) movements \u{00B7} \(test.organization.rawValue.uppercased()) \(test.year)")
                    }
                }

                // Start
                Section {
                    Button {
                        navigateToRide = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Ride", systemImage: "play.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(selectedTest == nil)
                }
            }
            .navigationTitle("Dressage Caller")
            .navigationDestination(isPresented: $navigateToRide) {
                RideView(
                    configuration: configuration,
                    calibration: calibration,
                    test: selectedTest,
                    horseName: horseName.isEmpty ? nil : horseName
                )
            }
        }
    }
}
