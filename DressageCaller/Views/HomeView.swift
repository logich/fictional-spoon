import AVFoundation
import SwiftUI

/// Landing screen for configuring arena, horse, and test before starting a ride.
struct HomeView: View {
    @Binding var importURL: URL?
    @State private var showingSharedImport = false
    @State private var library = TestLibrary()
    @State private var arenaSize: ArenaSize = .standard
    @State private var horseName: String = ""
    @State private var selectedTest: DressageTest? = SampleTests.trainingLevel1
    @State private var calibration: BeaconCalibration = .load()
    @State private var navigateToRide = false
    @State private var navigateToCalibration = false
    @State private var voiceRefreshToken = UUID()  // forces voice label to update after picker dismisses
    @State private var timingOffset: Double = 0.0
    @State private var practiceMode: Bool = false

    private var timingOffsetKey: String { "timingOffset_\(arenaSize.rawValue)" }

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

                // Beacons
                Section("Beacons") {
                    NavigationLink("Beacon Diagnostic") {
                        BeaconDiagnosticView()
                    }
                }

                // Calibration
                Section {
                    NavigationLink {
                        CalibrationView(configuration: configuration) { result in
                            calibration = result
                            result.save()
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
                        TestSelectionView(selectedTest: $selectedTest, arenaSize: arenaSize, library: library)
                    } label: {
                        HStack {
                            Text("Test")
                            Spacer()
                            Text(selectedTest?.name ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let test = selectedTest {
                        NavigationLink(destination: PreviewMovementsView(test: test)) {
                            Text("Preview Movements")
                        }
                    }
                } footer: {
                    if let test = selectedTest {
                        Text("\(test.movements.count) movements \u{00B7} \(test.organization.rawValue.uppercased()) \(test.year)")
                    }
                }

                // Timing
                Section {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Earlier")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(timingOffsetLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Later")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $timingOffset, in: -3...3, step: 0.5)
                            .onChange(of: timingOffset) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: timingOffsetKey)
                            }
                    }
                    Toggle("Practice Mode", isOn: $practiceMode)
                } header: {
                    Text("Timing")
                } footer: {
                    Text(practiceMode
                         ? "No start bell. Calling pauses when you halt for 5+ seconds."
                         : "Bell rings at entry; 45-second countdown before movements begin.")
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
                RideView(session: RideSession(
                    configuration: configuration,
                    calibration: calibration,
                    test: selectedTest,
                    horseName: horseName.isEmpty ? nil : horseName,
                    practiceMode: practiceMode,
                    timingOffset: timingOffset
                ))
            }
            .onAppear {
                timingOffset = UserDefaults.standard.object(forKey: timingOffsetKey) as? Double ?? 0.0
                library.load()
            }
            .onChange(of: importURL) { _, url in
                if url != nil { showingSharedImport = true }
            }
            .sheet(isPresented: $showingSharedImport, onDismiss: {
                importURL = nil
                library.load()
            }) {
                if let url = importURL {
                    TestImportView(library: library, fileURL: url)
                }
            }
            .onChange(of: arenaSize) { _, _ in
                timingOffset = UserDefaults.standard.object(forKey: timingOffsetKey) as? Double ?? 0.0
            }
        }
    }

    private var timingOffsetLabel: String {
        if timingOffset == 0 { return "0s" }
        return timingOffset > 0 ? "+\(String(format: "%.1f", timingOffset))s" : "\(String(format: "%.1f", timingOffset))s"
    }
}
