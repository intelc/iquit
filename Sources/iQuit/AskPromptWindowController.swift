import AppKit
import iQuitCore
import SwiftUI

@MainActor
final class AskPromptWindowController {
    private let cardSize = NSSize(width: 370, height: 114)
    private let panelPadding: CGFloat = 7
    private var panel: NSPanel?
    private var timeoutTask: Task<Void, Never>?
    private var currentCleanup: PendingCleanup?

    private var panelSize: NSSize {
        NSSize(width: cardSize.width + panelPadding * 2, height: cardSize.height + panelPadding * 2)
    }

    private let onHide: (PendingCleanup) -> Void
    private let onQuit: (PendingCleanup) -> Void
    private let onAlwaysHide: (PendingCleanup) -> Void
    private let onAlwaysQuit: (PendingCleanup) -> Void
    private let onIgnore: (PendingCleanup) -> Void
    private let onSkip: (PendingCleanup) -> Void
    private let onTimeout: (PendingCleanup) -> Void

    var isShowing: Bool {
        currentCleanup != nil
    }

    init(
        onHide: @escaping (PendingCleanup) -> Void,
        onQuit: @escaping (PendingCleanup) -> Void,
        onAlwaysHide: @escaping (PendingCleanup) -> Void,
        onAlwaysQuit: @escaping (PendingCleanup) -> Void,
        onIgnore: @escaping (PendingCleanup) -> Void,
        onSkip: @escaping (PendingCleanup) -> Void,
        onTimeout: @escaping (PendingCleanup) -> Void
    ) {
        self.onHide = onHide
        self.onQuit = onQuit
        self.onAlwaysHide = onAlwaysHide
        self.onAlwaysQuit = onAlwaysQuit
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
            onAlwaysHide: { [weak self] in self?.onAlwaysHide(cleanup) },
            onAlwaysQuit: { [weak self] in self?.onAlwaysQuit(cleanup) },
            onIgnore: { [weak self] in self?.onIgnore(cleanup) },
            onSkip: { [weak self] in self?.onSkip(cleanup) }
        )

        let host = NSHostingController(rootView: view)
        host.view.frame = NSRect(origin: .zero, size: panelSize)
        host.view.wantsLayer = true
        host.view.layer?.masksToBounds = false
        let panel = panel ?? makePanel()
        panel.contentViewController = host
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.masksToBounds = false
        panel.setContentSize(panelSize)
        self.panel = panel
        position(panel)
        panel.invalidateShadow()
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
        panel.hasShadow = false
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
    private static let cornerRadius: CGFloat = 16
    private static let cardWidth: CGFloat = 370
    private static let cardHeight: CGFloat = 114

    var cleanup: PendingCleanup
    var icon: NSImage?
    var onHide: () -> Void
    var onQuit: () -> Void
    var onAlwaysHide: () -> Void
    var onAlwaysQuit: () -> Void
    var onIgnore: () -> Void
    var onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            let remaining = max(0, cleanup.dueAt.timeIntervalSince(context.date))
            let total = max(1, cleanup.dueAt.timeIntervalSince(cleanup.createdAt))
            let progress = max(0, min(1, remaining / total))

            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    AppIconView(icon: icon, size: 34)

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

                    Button(action: onSkip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(PromptIconButtonStyle())
                    .help("Do nothing now. iQuit will wait before asking again.")
                }
                .padding(.horizontal, 14)
                .padding(.top, 11)
                .padding(.bottom, 8)

                HStack(spacing: 8) {
                    if cleanup.trigger == .visibleWindow {
                        PromptSplitActionButton(
                            title: "Hide",
                            systemImage: "eye.slash",
                            alwaysTitle: "Always Hide",
                            tint: .blue,
                            action: onHide,
                            alwaysAction: onAlwaysHide,
                            help: "Put this app's windows away. The app keeps running.",
                            alwaysHelp: "From now on, hide this app automatically when its windows are idle."
                        )
                    }

                    PromptSplitActionButton(
                        title: "Quit",
                        systemImage: "power",
                        alwaysTitle: "Always Quit",
                        tint: .red,
                        action: onQuit,
                        alwaysAction: onAlwaysQuit,
                        help: "Ask this app to close. It can still warn you about unsaved work.",
                        alwaysHelp: "From now on, quit this app automatically when this rule fires."
                    )

                    Button(action: onIgnore) {
                        Text("Never")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(PromptTextButtonStyle())
                    .help("Never let iQuit hide or quit this app automatically.")

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 9)

                Spacer(minLength: 0)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.12))
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 14)
                .padding(.bottom, 9)
                .accessibilityLabel("\(Int(remaining)) seconds remaining")
            }
            .frame(width: Self.cardWidth, height: Self.cardHeight, alignment: .top)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16))
            }
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.34), radius: 8, y: 3)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .padding(7)
    }
}

private struct PromptSplitActionButton: View {
    var title: String
    var systemImage: String
    var alwaysTitle: String
    var tint: Color
    var action: () -> Void
    var alwaysAction: () -> Void
    var help: String
    var alwaysHelp: String

    var body: some View {
        HStack(spacing: 2) {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(PromptActionButtonStyle(tint: tint))
            .controlSize(.small)
            .fixedSize()
            .help(help)

            Menu {
                Button(alwaysTitle, action: alwaysAction)
                    .help(alwaysHelp)
            } label: {
                Text("")
                    .frame(width: 16, height: 18)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(PromptChevronButtonStyle(tint: tint))
            .help(alwaysHelp)
        }
        .fixedSize()
    }
}

private struct PromptActionButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        PromptActionButtonBody(configuration: configuration, tint: tint)
    }
}

private struct PromptActionButtonBody: View {
    let configuration: ButtonStyle.Configuration
    var tint: Color
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                tint.opacity(configuration.isPressed ? 0.72 : (isHovering ? 1 : 0.92)),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(isHovering ? 0.28 : 0.0), lineWidth: 1)
            }
            .shadow(color: tint.opacity(isHovering ? 0.36 : 0), radius: isHovering ? 9 : 0, y: isHovering ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovering ? 1.035 : 1))
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

private struct PromptChevronButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        PromptChevronButtonBody(configuration: configuration, tint: tint)
    }
}

private struct PromptChevronButtonBody: View {
    let configuration: ButtonStyle.Configuration
    var tint: Color
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
            .background(
                tint.opacity(configuration.isPressed ? 0.62 : (isHovering ? 0.88 : 0.72)),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(isHovering ? 0.24 : 0), lineWidth: 1)
            }
            .shadow(color: tint.opacity(isHovering ? 0.28 : 0), radius: isHovering ? 7 : 0, y: isHovering ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovering ? 1.04 : 1))
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

private struct PromptIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PromptIconButtonBody(configuration: configuration)
    }
}

private struct PromptTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PromptTextButtonBody(configuration: configuration)
    }
}

private struct PromptTextButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(isHovering ? .primary : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.12 : (isHovering ? 0.16 : 0)),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(isHovering ? 0.18 : 0), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovering ? 0.28 : 0), radius: isHovering ? 7 : 0, y: isHovering ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovering ? 1.04 : 1))
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

private struct PromptIconButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(isHovering ? .primary : .secondary)
            .padding(7)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.12 : (isHovering ? 0.16 : 0)),
                in: Circle()
            )
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(isHovering ? 0.18 : 0), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovering ? 0.28 : 0), radius: isHovering ? 7 : 0, y: isHovering ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovering ? 1.08 : 1))
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}
