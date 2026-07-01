import AVFoundation
import Foundation

/// Owns in-chat voice-note playback — play, pause, resume, and stop.
@MainActor
@Observable
final class ChatVoiceNotePlaybackController: NSObject {
    private(set) var playbackState: PlaybackState = .idle
    private(set) var playbackCurrentTime: TimeInterval = 0
    private(set) var lastErrorMessage: String?
    private var player: AVAudioPlayer?
    private var activeAttachmentID: UUID?
    private var activeDuration: TimeInterval = 0
    private var progressTimer: Timer?

    enum PlaybackState: Equatable {
        case idle
        case playing(UUID)
        case paused(UUID)
    }

    func isPlaying(attachmentID: UUID) -> Bool {
        playbackState == .playing(attachmentID)
    }

    func isActive(attachmentID: UUID) -> Bool {
        switch playbackState {
        case let .playing(id), let .paused(id):
            return id == attachmentID
        case .idle:
            return false
        }
    }

    func displayedDuration(for attachment: ChatMessageAttachment) -> TimeInterval {
        ChatVoiceNotePlaybackDisplayLogic.displayedDuration(
            currentTime: playbackCurrentTime,
            totalDuration: resolvedDuration(for: attachment),
            isPlaybackActive: isActive(attachmentID: attachment.id)
        )
    }

    func playbackProgress(for attachment: ChatMessageAttachment) -> Double {
        guard isActive(attachmentID: attachment.id) else { return 0 }
        return ChatVoiceNotePlaybackDisplayLogic.playbackProgress(
            currentTime: playbackCurrentTime,
            duration: resolvedDuration(for: attachment)
        )
    }

    func toggle(attachment: ChatMessageAttachment) {
        guard attachment.kind == .audio else { return }

        switch playbackState {
        case .playing(attachment.id):
            pauseActivePlayback()
            return
        case .paused(attachment.id):
            resumeActivePlayback()
            return
        case .idle, .playing, .paused:
            break
        }

        stop()
        startPlayback(for: attachment)
    }

    func stop() {
        stopProgressTimer()
        player?.stop()
        player = nil
        activeAttachmentID = nil
        activeDuration = 0
        playbackCurrentTime = 0
        playbackState = .idle
    }

    private func startPlayback(for attachment: ChatMessageAttachment) {
        lastErrorMessage = nil
        let fileURL = attachment.fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            lastErrorMessage = "Voice note is no longer available."
            return
        }

        do {
            try activatePlaybackSession()
            let newPlayer = try AVAudioPlayer(contentsOf: fileURL)
            newPlayer.delegate = self
            newPlayer.volume = 1
            guard newPlayer.prepareToPlay() else {
                lastErrorMessage = "Voice note could not be played."
                return
            }

            let resolved = resolvedDuration(
                for: attachment,
                playerDuration: newPlayer.duration
            )
            guard resolved > 0 else {
                lastErrorMessage = "Voice note could not be played."
                return
            }

            player = newPlayer
            activeAttachmentID = attachment.id
            activeDuration = resolved
            playbackCurrentTime = 0
            startProgressTimer()
            guard newPlayer.play() else {
                lastErrorMessage = "Voice note could not be played."
                stop()
                return
            }
            playbackState = .playing(attachment.id)
        } catch {
            lastErrorMessage = "Voice note could not be played."
            stop()
        }
    }

    private func pauseActivePlayback() {
        syncProgressFromPlayer()
        player?.pause()
        if case let .playing(attachmentID) = playbackState {
            playbackState = .paused(attachmentID)
        }
        stopProgressTimer()
    }

    private func resumeActivePlayback() {
        do {
            try activatePlaybackSession()
        } catch {
            lastErrorMessage = "Voice note could not be played."
            stop()
            return
        }
        guard player?.play() == true else {
            lastErrorMessage = "Voice note could not be played."
            stop()
            return
        }
        startProgressTimer()
        if case let .paused(attachmentID) = playbackState {
            playbackState = .playing(attachmentID)
        }
    }

    private func resolvedDuration(
        for attachment: ChatMessageAttachment,
        playerDuration: TimeInterval? = nil
    ) -> TimeInterval {
        if isActive(attachmentID: attachment.id) {
            if activeDuration > 0 {
                return activeDuration
            }
            if let playerDuration, playerDuration > 0 {
                return playerDuration
            }
        }
        if let playerDuration, playerDuration > 0 {
            return playerDuration
        }
        return max(attachment.audioDuration, 0)
    }

    private func syncProgressFromPlayer() {
        guard let player else { return }
        playbackCurrentTime = max(0, player.currentTime)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player, player.isPlaying else { return }
                self.playbackCurrentTime = max(0, player.currentTime)
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func handlePlaybackEnded() {
        player?.currentTime = 0
        playbackCurrentTime = 0
        playbackState = .idle
        stopProgressTimer()
    }

    private func activatePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try session.setCategory(.playback, mode: .spokenAudio, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

extension ChatVoiceNotePlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handlePlaybackEnded()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            self?.lastErrorMessage = "Voice note could not be played."
            self?.stop()
        }
    }
}
