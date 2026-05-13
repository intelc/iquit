import AppKit
import iQuitCore
import SwiftUI

@MainActor
final class AskPromptWindowController {
    private let panelSize = NSSize(width: 430, height: 88)
    private var panel: NSPanel?
    private var timeoutTask: Task<Void, Never>?
    private var currentCleanup: PendingCleanup?

    private let onHide: (PendingCleanup) -> Void
    private let onQuit: (PendingCleanup) -> Void
    private let onIgnore: (PendingCleanup) -> Void
    private let onSkip: (PendingCleanup) -> Void
    private let onTimeout: (PendingCleanup) -> Void

    var isShowing: Bool {
        currentCleanup != nil
    }

    init(
        onHide: @escaping (PendingCleanup) -> Void,
        onQuit: @escaping (PendingCleanup) -> Void,
        onIgnore: @escaping (PendingCleanup) -> Void,
        onSkip: @escaping (PendingCleanup) -> Void,
        onTimeout: @escaping (PendingCleanup) -> Void
    ) {
        self.onHide = onHide
        self.onQuit = onQuit
        self.onIgnore = onIgnore
        self.onSkip = onSkip
        self.onTimeout = onTimeout
    }

    func show(cleanup: PendingCleanup, icon: NSImage?) {
        timeoutTask?.cancel()
        currentCleanup = cleanup

        let view = AskPromptView(
            cleanup: cleanup,
            icon: icon,
            onHide: { [weak self] in self?.onHide(cleanup) },
            onQuit: { [weak self] in self?.onQuit(cleanup) },
            onIgnore: { [weak self] in self?.onIgnore(cleanup) },
            onSkip: { [weak self] in self?.onSkip(cleanup) }
        )

        let host = NSHostingController(rootView: view)
        let panel = panel ?? makePanel()
        panel.contentViewController = host
        panel.setContentSize(panelSize)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()

        timeoutTask = Task { [weak self] in
            let delay = max(0, cleanup.dueAt.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.currentCleanup?.id == cleanup.id else { return }
                self?.onTimeout(cleanup)
            }
        }
    }

    func dismiss(ifShowing cleanup: PendingCleanup) {
        guard currentCleanup?.id == cleanup.id else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        currentCleanup = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = true
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let targetX = frame.maxX - size.width - 28
        let targetY = frame.maxY - size.height - 18
        let origin = NSPoint(
            x: min(max(targetX, frame.minX + 12), frame.maxX - size.width - 12),
            y: min(max(targetY, frame.minY + 12), frame.maxY - size.height - 12)
        )
        panel.setFrameOrigin(origin)
    }
}

private struct AskPromptView: View {
    var cleanup: PendingCleanup
    var icon: NSImage?
    var onHide: () -> Void
    var onQuit: () -> Void
    var onIgnore: () -> Void
    var onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let remaining = max(0, cleanup.dueAt.timeIntervalSince(context.date))
            let total = max(1, cleanup.dueAt.timeIntervalSince(cleanup.createdAt))
            let progress = max(0, min(1, remaining / total))

            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    AppIconView(icon: icon, size: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(cleanup.displayName) \(cleanup.trigger.titleSuffix)")
                            .font(.headline)
                            .lineLimit(1)
                        Text(cleanup.trigger.subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 104, maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 4)

                    if cleanup.trigger == .visibleWindow {
                        Button(action: onHide) {
                            Label("Hide", systemImage: "eye.slash")
                        }
                        .buttonStyle(PromptActionButtonStyle(tint: .blue))
                        .controlSize(.small)
                        .fixedSize()
                    }

                    Button(role: .destructive, action: onQuit) {
                        Label("Quit", systemImage: "power")
                    }
                    .buttonStyle(PromptActionButtonStyle(tint: .red))
                    .controlSize(.small)
                    .fixedSize()

                    Button(action: onIgnore) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .help("Ignore this app")

                    Button(action: onSkip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .help("Do nothing")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.accentColor)
                        .frame(width: proxy.size.width * progress)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 3)
                .accessibilityLabel("\(Int(remaining)) seconds remaining")
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.16))
            }
        }
        .frame(width: 430, height: 88)
    }
}

private struct PromptActionButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                tint.opacity(configuration.isPressed ? 0.72 : 0.92),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}
