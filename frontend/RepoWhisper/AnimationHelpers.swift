//
//  AnimationHelpers.swift
//  RepoWhisper
//
//  Modern animations and styling helpers.
//

import SwiftUI

// MARK: - Custom Animations

extension Animation {
    /// Smooth spring animation for UI interactions
    static let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)
    
    /// Quick spring for button presses
    static let quickSpring = Animation.spring(response: 0.2, dampingFraction: 0.8, blendDuration: 0)
    
    /// Bouncy animation for appearance
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
}

// MARK: - Custom Gradients

extension LinearGradient {
    /// Purple to blue gradient (brand colors)
    static let brandGradient = LinearGradient(
        colors: [.purple, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Success gradient
    static let successGradient = LinearGradient(
        colors: [.green, .mint],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Warning gradient
    static let warningGradient = LinearGradient(
        colors: [.yellow, .orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Error gradient
    static let errorGradient = LinearGradient(
        colors: [.red, .pink],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Subtle background gradient
    static let subtleBackground = LinearGradient(
        colors: [Color.purple.opacity(0.08), Color.blue.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Custom View Modifiers

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct PulsatingDot: ViewModifier {
    @State private var isPulsating = false
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(isPulsating ? 1.5 : 1.0)
                    .opacity(isPulsating ? 0 : 1)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsating
                    )
                    .onAppear { isPulsating = true }
            )
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

struct PressableButton: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? -0.05 : 0)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.quickSpring) {
                    isPressed = pressing
                }
            }, perform: {})
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glass card styling
    func glassCard(cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 8) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    /// Add pulsating effect
    func pulsating(color: Color = .blue) -> some View {
        modifier(PulsatingDot(color: color))
    }
    
    /// Add shimmer effect
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
    
    /// Make button pressable with scale animation
    func pressable() -> some View {
        modifier(PressableButton())
    }
    
    /// Appear with fade and slide animation
    func appearWithSlide(delay: Double = 0) -> some View {
        self
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(.smoothSpring.delay(delay), value: UUID())
    }
}

// MARK: - Loading Indicators

struct PulsingCircles: View {
    @State private var animating = false
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

struct WaveformAnimation: View {
    @State private var animating = false
    var isActive: Bool
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3)
                    .frame(height: animating ? CGFloat.random(in: 6...20) : 6)
                    .animation(
                        isActive ?
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.1) :
                            .default,
                        value: animating
                    )
            }
        }
        .onChange(of: isActive) { _, newValue in
            animating = newValue
        }
        .onAppear {
            if isActive {
                animating = true
            }
        }
    }
}

// MARK: - Badge Components

struct StatusBadge: View {
    var text: String
    var color: Color
    var icon: String?
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview Helpers

#Preview("Animations") {
    VStack(spacing: 30) {
        PulsingCircles(color: .purple)
        
        WaveformAnimation(isActive: true, color: .blue)
        
        StatusBadge(text: "45ms", color: .green, icon: "bolt.fill")
        
        Text("Glass Card")
            .padding()
            .glassCard()
        
        Circle()
            .fill(.red)
            .frame(width: 12, height: 12)
            .pulsating(color: .red)
    }
    .padding()
    .frame(width: 300, height: 400)
    .background(.black.opacity(0.5))
}

