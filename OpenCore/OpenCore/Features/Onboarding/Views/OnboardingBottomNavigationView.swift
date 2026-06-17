import SwiftUI

/// Bottom navigation — pagination dots + back/continue action row.
struct OnboardingBottomNavigationView: View {
    @Bindable var flow: OnboardingFlowController

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(0..<flow.state.totalPages, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            flow.dispatch(OnboardingSelectPageCommand(index: index))
                        }
                    } label: {
                        Capsule(style: .continuous)
                            .fill(index == flow.state.currentPage ? palette.accentPrimary : palette.lineSoft)
                            .frame(width: index == flow.state.currentPage ? 28 : 6, height: 6)
                            .animation(.spring(response: 0.34, dampingFraction: 0.76), value: flow.state.currentPage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to onboarding page \(index + 1)")
                }
            }

            HStack(spacing: 10) {
                if flow.state.currentPage > 0 {
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            flow.dispatch(OnboardingRetreatPageCommand())
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("BACK")
                        }
                    }
                    .buttonStyle(SharedSecondaryButtonStyle(palette: palette))
                    .accessibilityLabel("Previous onboarding page")
                }

                Button {
                    if flow.state.isLastPage {
                        Task { await flow.finish() }
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            flow.dispatch(OnboardingAdvancePageCommand())
                        }
                    }
                } label: {
                    HStack(spacing: 9) {
                        Text(flow.state.isLastPage ? "ENTER OPENCORE" : "CONTINUE")
                        Image(systemName: flow.state.isLastPage ? "arrow.up.right" : "arrow.right")
                    }
                }
                .buttonStyle(SharedPrimaryButtonStyle(palette: palette))
                .accessibilityLabel(flow.state.isLastPage ? "Enter OpenCore" : "Continue onboarding")
            }
        }
    }
}
