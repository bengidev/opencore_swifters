import SwiftUI

struct ModelInputCapabilityIconsView: View {
    let capabilities: ModelInputCapabilities
    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            if capabilities.supportsFileInput {
                icon("doc.text", label: "Supports file input")
            }
            if capabilities.supportsImageInput {
                icon("eye", label: "Supports image input")
            }
            if capabilities.supportsVideoInput {
                icon("video", label: "Supports video input")
            }
            if capabilities.supportsAudioInput {
                icon("waveform", label: "Supports audio input")
            }
        }
    }

    private func icon(_ name: String, label: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(palette.textTertiary)
            .accessibilityLabel(label)
    }
}
