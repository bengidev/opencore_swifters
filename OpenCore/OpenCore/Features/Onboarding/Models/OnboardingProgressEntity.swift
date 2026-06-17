import Foundation
import SwiftData

/// SwiftData model for persisting onboarding completion state.
@Model
final class OnboardingProgressEntity {
    var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isCompleted = isCompleted
    }
}
