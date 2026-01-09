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
    private var popupWindow: NSPanel?
    
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
            isRecording: isRecording
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
        let windowHeight: CGFloat = 520
        let padding: CGFloat = 20
        
        // Position at top-right
        let xPos = screenFrame.maxX - windowWidth - padding
        let yPos = screenFrame.maxY - windowHeight - padding
        
        let windowFrame = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )
        
        // Create the popup panel
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel appearance
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        
        // Store and show
        self.popupWindow = panel
        self.isVisible = true
        
        print("📺 [POPUP] Window created at position: x=\(xPos), y=\(yPos), size=\(windowWidth)x\(windowHeight)")
        
        // Animate in
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        print("✅ [POPUP] Window ordered front - should be visible now!")
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }, completionHandler: {
            print("✨ [POPUP] Animation complete - window fully visible")
        })
        
        // Auto-dismiss after 15 seconds (like Cluely)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.hidePopup()
        }
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
            isRecording: isRecording
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (top-right corner of screen with padding)
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Window size (premium glassmorphism)
        let windowWidth: CGFloat = 580
        let windowHeight: CGFloat = 520
        let padding: CGFloat = 20
        
        // Position at top-right
        let xPos = screenFrame.maxX - windowWidth - padding
        let yPos = screenFrame.maxY - windowHeight - padding
        
        let windowFrame = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )
        
        // Create the popup panel
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel appearance
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        
        // Store and show
        self.popupWindow = panel
        self.isVisible = true
        
        // Animate in
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }, completionHandler: nil)
        
        // Auto-dismiss after 15 seconds (like Cluely)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.hidePopup()
        }
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

