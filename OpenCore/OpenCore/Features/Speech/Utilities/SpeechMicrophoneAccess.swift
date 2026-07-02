import AVFAudio
import Foundation

/// Microphone permission helpers for speech capture.
nonisolated enum SpeechMicrophoneAccess: Sendable {
    static func authorizationStatus() -> SpeechAuthorizationStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            .authorized
        case .denied:
            .denied
        case .undetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }

    static func requestAuthorization() async -> SpeechAuthorizationStatus {
        switch authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            return granted ? .authorized : .denied
        }
    }
}
