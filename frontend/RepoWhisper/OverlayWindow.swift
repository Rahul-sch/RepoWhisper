//
//  OverlayWindow.swift
//  RepoWhisper
//
//  Custom NSPanel with stealth properties for invisible overlay.
//  Ported from free-cluely's Electron window configuration.
//

import AppKit
import SwiftUI

/// Custom NSPanel with stealth overlay capabilities
final class OverlayWindow: NSPanel {
    private var hostingView: NSHostingView<AnyView>?
    private(set) var isStealthModeEnabled: Bool = false

    init(contentRect: NSRect, content: some View, stealth: Bool = false) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isStealthModeEnabled = stealth
        configureWindow()
        setContent(content)
    }

    private func configureWindow() {
        // Transparency
        isOpaque = false
        backgroundColor = .clear

        // Window level (above menu bar but below alerts)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)

        // System UI hiding
        collectionBehavior = [
            .canJoinAllSpaces,        // Visible on all desktops
            .fullScreenAuxiliary,     // Show over fullscreen apps
            .stationary,              // Hidden from Mission Control
            .ignoresCycle             // Skip Cmd+Tab
        ]

        // Interaction
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isFloatingPanel = true

        // Apply stealth settings
        applyStealth(isStealthModeEnabled)
    }

    /// Toggle stealth mode on/off
    func applyStealth(_ enabled: Bool) {
        isStealthModeEnabled = enabled

        // Screen-share invisibility (KEY FEATURE)
        // .none = invisible in screen shares
        // .readOnly = visible but not interactive
        sharingType = enabled ? .none : .readOnly
        hasShadow = !enabled

        // Opacity
        let targetAlpha: CGFloat = enabled ? 0.7 : 1.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().alphaValue = targetAlpha
        }
    }

    /// Set SwiftUI content
    func setContent(_ content: some View) {
        let hostingView = NSHostingView(rootView: AnyView(content))
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
        self.hostingView = hostingView
    }

    /// Enable/disable click-through
    func setClickThrough(_ enabled: Bool) {
        ignoresMouseEvents = enabled
    }

    // MARK: - Animations

    func fadeIn(duration: TimeInterval = 0.2, targetAlpha: CGFloat? = nil) {
        let alpha = targetAlpha ?? (isStealthModeEnabled ? 0.7 : 1.0)
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = alpha
        }
    }

    func fadeOut(duration: TimeInterval = 0.15, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        }
    }

    // MARK: - Positioning

    func positionTopRight(padding: CGFloat = 20) {
        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.maxX - frame.width - padding
        let y = screen.visibleFrame.maxY - frame.height - padding
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func positionBottomRight(padding: CGFloat = 20) {
        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.maxX - frame.width - padding
        let y = screen.visibleFrame.minY + padding
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func positionCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func move(by offset: NSPoint) {
        let newOrigin = NSPoint(
            x: frame.origin.x + offset.x,
            y: frame.origin.y + offset.y
        )
        setFrameOrigin(newOrigin)
    }
}
