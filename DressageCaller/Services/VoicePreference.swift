import AVFoundation
import Foundation

/// Manages the rider's preferred TTS voice, persisted across launches.
enum VoicePreference {

    static let userDefaultsKey = "callerVoiceIdentifier"

    /// Returns the preferred voice if still installed, otherwise the best available English voice.
    static func resolvedVoice() -> AVSpeechSynthesisVoice {
        if let id = UserDefaults.standard.string(forKey: userDefaultsKey),
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return bestAvailableVoice() ?? AVSpeechSynthesisVoice(language: "en-US")!
    }

    /// Saves the chosen voice identifier.
    static func save(identifier: String) {
        UserDefaults.standard.set(identifier, forKey: userDefaultsKey)
    }

    /// Clears any saved preference so the automatic best-voice logic takes over.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// The identifier of the currently saved preference (nil = automatic).
    static var savedIdentifier: String? {
        UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    /// All installed English voices, sorted premium → enhanced → default, then by name.
    static func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted {
                if $0.quality != $1.quality { return $0.quality.sortOrder > $1.quality.sortOrder }
                return $0.name < $1.name
            }
    }

    // MARK: - Private

    private static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let voices = availableEnglishVoices()
        return voices.first(where: { $0.quality == .premium })
            ?? voices.first(where: { $0.quality == .enhanced })
            ?? voices.first
    }
}

extension AVSpeechSynthesisVoiceQuality {
    var sortOrder: Int {
        switch self {
        case .premium:  return 3
        case .enhanced: return 2
        default:        return 1
        }
    }

    var label: String {
        switch self {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Default"
        }
    }
}
