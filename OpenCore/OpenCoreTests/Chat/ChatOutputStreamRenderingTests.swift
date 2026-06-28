import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Output Stream Humanizer")
struct ChatOutputStreamHumanizerTests {
    @Test("Unwraps shell-wrapped commands")
    func unwrapsShellWrappedCommands() {
        let info = ChatOutputStreamHumanizer.humanize(
            "/usr/bin/bash -lc \"cd /tmp/project && npm install\"",
            isRunning: true
        )
        #expect(info.verb == "Running")
        #expect(info.target == "npm install")
    }

    @Test("Humanizes read commands")
    func humanizesReadCommands() {
        let running = ChatOutputStreamHumanizer.humanize(
            "nl -ba OpenCore/Features/Chat/Views/ChatView.swift",
            isRunning: true
        )
        #expect(running.verb == "Reading")
        #expect(running.target == "Views/ChatView.swift")

        let completed = ChatOutputStreamHumanizer.humanize(
            "nl -ba OpenCore/Features/Chat/Views/ChatView.swift",
            isRunning: false
        )
        #expect(completed.verb == "Read")
    }

    @Test("Humanizes search commands")
    func humanizesSearchCommands() {
        let info = ChatOutputStreamHumanizer.humanize(
            "rg -n \"streaming\" OpenCore",
            isRunning: false
        )
        #expect(info.verb == "Searched")
        #expect(info.target == "for streaming in OpenCore")
    }
}

@Suite("Chat Output Stream Detail")
struct ChatOutputStreamDetailTests {
    @Test("Trims output tail to max lines")
    func trimsOutputTail() {
        var detail = ChatOutputStreamDetail()
        let lines = (1...40).map { "line \($0)" }.joined(separator: "\n")
        detail.appendOutput(lines)

        let keptLines = detail.outputTail.components(separatedBy: .newlines)
        #expect(keptLines.count == ChatOutputStreamDetail.maxOutputLines)
        #expect(keptLines.first == "line 11")
        #expect(keptLines.last == "line 40")
    }
}

/// Output-stream streaming regression tests for `ChatFlowController`.
@MainActor
@Suite("Chat Output Stream Streaming")
struct ChatOutputStreamStreamingTests {
    private func outputStreamMessages(_ state: ChatFlowState) -> [ChatOutputStreamMessage] {
        state.messages.compactMap {
            if case let .outputStream(message) = $0 { return message }
            return nil
        }
    }

    private func makeController(
        events: [ChatStreamingEvent],
        ids: [UUID] = (0..<20).map { i in
            var bytes = [UInt8](repeating: 0, count: 16)
            bytes[15] = UInt8(i)
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    ) -> ChatFlowController {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        var idIndex = 0
        return ChatFlowController(
            streaming: ChatCannedEventClient(events: events).asStreamingClient,
            providerPreference: preference,
            makeID: {
                defer { idIndex += 1 }
                return ids[idIndex % ids.count]
            },
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    @Test("Output stream deltas merge into one row")
    func outputStreamDeltasMerge() async {
        let controller = makeController(events: [
            .outputStreamBegan(command: "npm test", cwd: "/tmp/project"),
            .outputStreamDelta("PASS "),
            .outputStreamDelta("suite\n"),
            .outputStreamEnded(status: .completed, exitCode: 0, durationMs: 1200),
            .textDelta("All checks passed."),
            .done
        ])

        controller.setDraftMessage("Run tests")
        await controller.sendMessage()

        let rows = outputStreamMessages(controller.state)
        #expect(rows.count == 1)
        #expect(rows.first?.command == "npm test")
        #expect(rows.first?.detail.cwd == "/tmp/project")
        #expect(rows.first?.detail.outputTail == "PASS suite\n")
        #expect(rows.first?.detail.status == .completed)
        #expect(rows.first?.detail.exitCode == 0)
        #expect(rows.first?.detail.durationMs == 1200)
        #expect(rows.first?.isComplete == true)
    }

    @Test("Sequential output streams create separate rows")
    func sequentialOutputStreams() async {
        let controller = makeController(events: [
            .outputStreamBegan(command: "git status", cwd: nil),
            .outputStreamEnded(status: .completed, exitCode: 0, durationMs: 50),
            .outputStreamBegan(command: "npm run lint", cwd: nil),
            .outputStreamDelta("ok\n"),
            .outputStreamEnded(status: .completed, exitCode: 0, durationMs: 80),
            .done
        ])

        controller.setDraftMessage("Check repo")
        await controller.sendMessage()

        let rows = outputStreamMessages(controller.state)
        #expect(rows.count == 2)
        #expect(rows[0].command == "git status")
        #expect(rows[1].command == "npm run lint")
        #expect(rows[1].detail.outputTail == "ok\n")
    }

    @Test("Error mid-stream finalizes output stream as failed")
    func errorMidStreamFinalizes() async {
        let controller = makeController(events: [
            .outputStreamBegan(command: "npm test", cwd: "/tmp/project"),
            .outputStreamDelta("partial\n"),
            .error("Connection lost."),
        ])

        controller.setDraftMessage("Run tests")
        await controller.sendMessage()

        let rows = outputStreamMessages(controller.state)
        #expect(rows.count == 1)
        #expect(rows.first?.command == "npm test")
        #expect(rows.first?.detail.outputTail == "partial\n")
        #expect(rows.first?.detail.status == .failed)
        #expect(rows.first?.isComplete == true)
        #expect(controller.state.streamingStatus == .failed)
        #expect(controller.state.streamErrorMessage == "Connection lost.")
    }

    @Test("Cancel mid-stream finalizes output stream as failed")
    func cancelMidStreamFinalizes() async {
        final class AppendedMessages: @unchecked Sendable {
            private let lock = NSLock()
            private var messages: [ChatMessage] = []

            func append(_ message: ChatMessage) {
                lock.lock()
                messages.append(message)
                lock.unlock()
            }

            func snapshot() -> [ChatMessage] {
                lock.lock()
                defer { lock.unlock() }
                return messages
            }
        }

        let appended = AppendedMessages()
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let streaming = ChatStreamingClient(stream: { _ in
            AsyncStream { continuation in
                continuation.yield(.outputStreamBegan(command: "npm test", cwd: nil))
                continuation.yield(.outputStreamDelta("partial\n"))
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    continuation.yield(.done)
                    continuation.finish()
                }
            }
        })
        let controller = ChatFlowController(
            streaming: streaming,
            history: ChatHistoryClient(
                loadMessages: { _ in [] },
                saveConversation: { _ in },
                appendMessage: { _, message in appended.append(message) },
                replaceMessages: { _, _ in }
            ),
            providerPreference: preference,
            now: { Date(timeIntervalSince1970: 0) }
        )

        controller.setDraftMessage("Run tests")
        let sendTask = Task { await controller.sendMessage() }
        try? await Task.sleep(nanoseconds: 150_000_000)
        controller.clearActiveConversation()
        await sendTask.value

        let persisted = appended.snapshot().compactMap { message -> ChatOutputStreamMessage? in
            if case let .outputStream(outputStream) = message { return outputStream }
            return nil
        }
        #expect(persisted.count == 1)
        #expect(persisted.first?.command == "npm test")
        #expect(persisted.first?.detail.outputTail == "partial\n")
        #expect(persisted.first?.detail.status == .failed)
        #expect(persisted.first?.isComplete == true)
    }
}
