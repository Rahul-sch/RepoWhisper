//
//  FloatingPopupManager.swift
//  RepoWhisper
//
//  Manages floating popup windows that appear on screen (Cluely-style).
//

import SwiftUI
import AppKit

/// Manages floating popup windows that appear on screen
class FloatingPopupManager: ObservableObject {
    static let shared = FloatingPopupManager()

    @Published var isVisible = false
    @Published var isStealthMode = false
    private var popupWindow: NSPanel?
    private var savedPosition: NSPoint?
    private var autoDismissTask: DispatchWorkItem?

    private init() {}
    
    /// Show the floating popup with search results
    func showPopup(results: [SearchResultItem], query: String, latency: Double, isRecording: Bool) {
        print("🎯 [POPUP] showPopup called with \(results.count) results, query: '\(query)'")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ [POPUP] self is nil, aborting")
                return
            }
            
            print("✅ [POPUP] Creating popup window...")
            // Close existing window if any (with delay to prevent ViewBridge errors)
            if let existingWindow = self.popupWindow {
                print("🔄 [POPUP] Closing existing window first")
                // Animate out first
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    existingWindow.animator().alphaValue = 0
                }, completionHandler: {
                    existingWindow.close()
                    self.popupWindow = nil
                    // Delay to let the window fully close before creating new one
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.createAndShowPopup(results: results, query: query, latency: latency, isRecording: isRecording)
                    }
                })
            } else {
                self.createAndShowPopup(results: results, query: query, latency: latency, isRecording: isRecording)
            }
        }
    }
    
    private func createAndShowPopup(results: [SearchResultItem], query: String, latency: Double, isRecording: Bool) {
        print("🎨 [POPUP] createAndShowPopup - creating window with \(results.count) results")
        // Create the SwiftUI view
        let contentView = ResultsWindow(
            results: results,
            query: query,
            latencyMs: latency,
            isLoading: false,
            isRecording: isRecording,
            isStealthMode: isStealthMode
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)
        print("✅ [POPUP] Created hosting view")
            
        // Calculate position (top-right corner of screen with padding)
        guard let screen = NSScreen.main else {
            print("❌ [POPUP] No main screen found!")
            return
        }
        print("✅ [POPUP] Got main screen: \(screen.frame)")
        let screenFrame = screen.visibleFrame

        // Window size (premium glassmorphism)
        let windowWidth: CGFloat = 580
        let windowHeight: CGFloat = isStealthMode ? 460 : 560
        let padding: CGFloat = 20

        // Position at top-right (or bottom-right in stealth)
        let xPos = screenFrame.maxX - windowWidth - padding
        let yPos = isStealthMode
            ? screenFrame.minY + padding
            : screenFrame.maxY - windowHeight - padding

        let windowFrame = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )

        // Create the popup panel with stealth support
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel appearance
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,       // Hidden from Mission Control
            .ignoresCycle      // Skip Cmd+Tab
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = !isStealthMode
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        // Screen-share invisibility ONLY in stealth mode
        panel.sharingType = isStealthMode ? .none : .readOnly

        // Store and show
        self.popupWindow = panel
        self.isVisible = true

        print("📺 [POPUP] Window created at position: x=\(xPos), y=\(yPos), size=\(windowWidth)x\(windowHeight), stealth=\(isStealthMode)")
        
        // Animate in
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        print("✅ [POPUP] Window ordered front - should be visible now!")

        let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = targetAlpha
        }, completionHandler: {
            print("✨ [POPUP] Animation complete - window fully visible")
        })

        // Auto-dismiss (15s normal, 30s stealth)
        autoDismissTask?.cancel()
        let dismissDelay: Double = isStealthMode ? 30 : 15
        let task = DispatchWorkItem { [weak self] in
            self?.hidePopup()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }
    
    /// Show the popup in loading state
    func showLoadingPopup(query: String, isRecording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Close existing window if any (with delay to prevent ViewBridge errors)
            if let existingWindow = self.popupWindow {
                // Animate out first
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    existingWindow.animator().alphaValue = 0
                }, completionHandler: {
                    existingWindow.close()
                    self.popupWindow = nil
                    // Delay to let the window fully close before creating new one
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.createAndShowLoadingPopup(query: query, isRecording: isRecording)
                    }
                })
            } else {
                self.createAndShowLoadingPopup(query: query, isRecording: isRecording)
            }
        }
    }
    
    private func createAndShowLoadingPopup(query: String, isRecording: Bool) {
        // Create the SwiftUI view with loading state
        let contentView = ResultsWindow(
            results: [],
            query: query,
            latencyMs: 0,
            isLoading: true,
            isRecording: isRecording,
            isStealthMode: isStealthMode
        )

        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)

        // Calculate position (top-right corner of screen with padding)
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Window size
        let windowWidth: CGFloat = 580
        let windowHeight: CGFloat = isStealthMode ? 460 : 560
        let padding: CGFloat = 20

        // Position at top-right (or bottom-right in stealth)
        let xPos = screenFrame.maxX - windowWidth - padding
        let yPos = isStealthMode
            ? screenFrame.minY + padding
            : screenFrame.maxY - windowHeight - padding

        let windowFrame = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )

        // Create the popup panel with stealth support
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel appearance
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = !isStealthMode
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        panel.sharingType = isStealthMode ? .none : .readOnly

        // Store and show
        self.popupWindow = panel
        self.isVisible = true

        // Animate in
        let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = targetAlpha
        }, completionHandler: nil)

        // Auto-dismiss (15s normal, 30s stealth)
        autoDismissTask?.cancel()
        let dismissDelay: Double = isStealthMode ? 30 : 15
        let task = DispatchWorkItem { [weak self] in
            self?.hidePopup()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }

    // MARK: - Stealth Mode Controls

    /// Toggle stealth mode on/off
    func toggleStealthMode() {
        isStealthMode.toggle()
        print("🥷 [POPUP] Stealth mode: \(isStealthMode ? "ON" : "OFF")")

        guard let panel = popupWindow else { return }

        // Update panel properties
        panel.hasShadow = !isStealthMode
        panel.sharingType = isStealthMode ? .none : .readOnly

        // Animate opacity change
        let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = targetAlpha
        }

        // Reset auto-dismiss with new timing
        autoDismissTask?.cancel()
        let dismissDelay: Double = isStealthMode ? 30 : 15
        let task = DispatchWorkItem { [weak self] in
            self?.hidePopup()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }

    /// Show and center the popup window
    func centerAndShow() {
        guard let panel = popupWindow, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        if !isVisible {
            let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = targetAlpha
            }
            isVisible = true
        }
    }

    /// Toggle popup visibility (show/hide with position memory)
    func toggleVisibility() {
        guard let panel = popupWindow else { return }

        if isVisible {
            savedPosition = panel.frame.origin
            hidePopup()
        } else {
            if let pos = savedPosition {
                panel.setFrameOrigin(pos)
            }
            let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = targetAlpha
            }
            isVisible = true
        }
    }

    /// Move window by offset
    func moveWindow(direction: NSPoint) {
        guard let panel = popupWindow else { return }
        let newOrigin = NSPoint(
            x: panel.frame.origin.x + direction.x,
            y: panel.frame.origin.y + direction.y
        )
        panel.setFrameOrigin(newOrigin)
    }

    /// Hide the floating popup
    func hidePopup() {
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.popupWindow else { return }
            
            // Animate out
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil) // Use orderOut instead of close for smoother transition
                // Delay before clearing to prevent ViewBridge errors
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    panel.close()
                    self?.popupWindow = nil
                    self?.isVisible = false
                }
            })
        }
    }
    
    /// Toggle popup visibility
    func togglePopup() {
        if self.isVisible {
            hidePopup()
        }
    }
}

