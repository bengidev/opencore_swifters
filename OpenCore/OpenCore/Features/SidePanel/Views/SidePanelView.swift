import SwiftUI

/// Host view for the side panel. Composes the session sidebar drawer and the
/// settings sheet presentation. The parent (HomeView) owns the flow controller
/// and passes it here for rendering.
struct SidePanelView: View {
    @Bindable var flow: SidePanelFlowController
    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ZStack {
            SidePanelSessionSidebarView(flow: flow.session)
        }
        .sheet(isPresented: Binding(
            get: { flow.setting != nil },
            set: { if !$0 { flow.dismissSettings() } }
        )) {
            if let setting = flow.setting {
                SidePanelSettingView(flow: setting)
            }
        }
    }
}
