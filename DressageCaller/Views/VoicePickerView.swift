import AVFoundation
import SwiftUI

/// Lets the rider pick a TTS voice from all English voices installed on the device.
struct VoicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIdentifier: String? = VoicePreference.savedIdentifier
    @State private var previewSynthesizer = AVSpeechSynthesizer()

    private let voices = VoicePreference.availableEnglishVoices()

    private var grouped: [(quality: AVSpeechSynthesisVoiceQuality, voices: [AVSpeechSynthesisVoice])] {
        let qualities: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]
        return qualities.compactMap { q in
            let group = voices.filter { $0.quality == q }
            return group.isEmpty ? nil : (q, group)
        }
    }

    var body: some View {
        List {
            automaticRow

            Section {
                Label(
                    "To download Premium or Enhanced voices, go to:\nSettings → Accessibility → Spoken Content → Voices",
                    systemImage: "info.circle"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            ForEach(grouped, id: \.quality.rawValue) { group in
                Section(group.quality.label) {
                    ForEach(group.voices, id: \.identifier) { voice in
                        voiceRow(voice)
                    }
                }
            }
        }
        .navigationTitle("Caller Voice")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rows

    private var automaticRow: some View {
        Button {
            selectedIdentifier = nil
            VoicePreference.clear()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatic")
                        .foregroundStyle(.primary)
                    Text("Best available voice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedIdentifier == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        Button {
            selectedIdentifier = voice.identifier
            VoicePreference.save(identifier: voice.identifier)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .foregroundStyle(.primary)
                    Text(voice.language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    preview(voice)
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

                if selectedIdentifier == voice.identifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    // MARK: - Preview

    private func preview(_ voice: AVSpeechSynthesisVoice) {
        previewSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "A — Enter working trot, rising. Proceed down centre line.")
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        previewSynthesizer.speak(utterance)
    }


}
