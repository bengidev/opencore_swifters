import SwiftUI

/// Host view for the side panel session sidebar drawer.
struct SidePanelView: View {
    @Bindable var flow: SidePanelFlowController

    var body: some View {
        SidePanelSessionSidebarView(flow: flow.session)
    }
}
