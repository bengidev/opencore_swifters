import Foundation

/// Queue item shown in the Prompt Queue page demo.
struct OnboardingQueueItem: Equatable, Sendable, Identifiable {
    enum Status: String, Equatable, Sendable {
        case running = "RUNNING"
        case next = "NEXT"
        case queued = "QUEUED"
        case ready = "READY"
    }

    var id: String { title }
    let title: String
    let detail: String
    let status: Status

    init(title: String, detail: String, status: Status) {
        self.title = title
        self.detail = detail
        self.status = status
    }

    static let samples: [OnboardingQueueItem] = [
        OnboardingQueueItem(title: "Map onboarding state", detail: "Engine already owns current page", status: .running),
        OnboardingQueueItem(title: "Generate interface cards", detail: "No vertical scroll, compact content", status: .next),
        OnboardingQueueItem(title: "Persist completion", detail: "Storage writes local progress", status: .queued),
        OnboardingQueueItem(title: "Review model budget", detail: "Reasoning slider updates the run", status: .ready)
    ]
}
