import AVFoundation
import Foundation

/// Owns in-chat voice-note playback — play, pause, resume, and stop.
@MainActor
@Observable
final class ChatVoiceNotePlaybackController: NSObject {
    private(set) var playbackState: PlaybackState = .idle
    private(set) var playbackCurrentTime: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var activeDuration: TimeInterval = 0
    private var progressTask: Task<Void, Never>?

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
        stopProgressUpdates()
        player?.stop()
        player = nil
        activeDuration = 0
        playbackCurrentTime = 0
        playbackState = .idle
    }

    private func startPlayback(for attachment: ChatMessageAttachment) {
        do {
            activatePlaybackSession()
            let newPlayer = try AVAudioPlayer(contentsOf: attachment.fileURL)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            activeDuration = resolvedDuration(for: attachment, playerDuration: newPlayer.duration)
            playbackCurrentTime = 0
            playbackState = .playing(attachment.id)
            newPlayer.play()
            startProgressUpdates()
        } catch {
            stop()
        }
    }

    private func pauseActivePlayback() {
        syncProgressFromPlayer()
        player?.pause()
        stopProgressUpdates()
        if case let .playing(attachmentID) = playbackState {
            playbackState = .paused(attachmentID)
        }
    }

    private func resumeActivePlayback() {
        activatePlaybackSession()
        player?.play()
        if case let .paused(attachmentID) = playbackState {
            playbackState = .playing(attachmentID)
        }
        startProgressUpdates()
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
        return max(attachment.audioDuration, 0)
    }

    private func syncProgressFromPlayer() {
        playbackCurrentTime = player?.currentTime ?? 0
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let player = self.player, player.isPlaying else { return }
                self.playbackCurrentTime = player.currentTime
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}

extension ChatVoiceNotePlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayerID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self,
                  let activePlayer = self.player,
                  ObjectIdentifier(activePlayer) == finishedPlayerID else {
                return
            }
            activePlayer.currentTime = 0
            stopProgressUpdates()
            self.player = nil
            activeDuration = 0
            playbackCurrentTime = 0
            playbackState = .idle
        }
    }
}
