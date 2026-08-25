//
//  LoginView.swift
//  RepoWhisper
//
//  Authentication login view.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            OverlayTheme.canvas.ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo and title
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(OverlayTheme.accent)
                        .frame(width: 48, height: 48)
                        .background(OverlayTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                    Text("RepoWhisper")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(OverlayTheme.textPrimary)

                    Text("Your private, real-time code assistant")
                        .font(.system(size: 12))
                        .foregroundStyle(OverlayTheme.textSecondary)
                }
                .padding(.top, 28)

                // Form fields (hide when authenticated)
                if !authManager.isAuthenticated {
                    VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(OverlayTheme.textSecondary)

                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(OverlayTheme.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius))
                            .overlay(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius).stroke(OverlayTheme.border))
                            .foregroundStyle(OverlayTheme.textPrimary)
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundStyle(OverlayTheme.textSecondary)

                        SecureField("••••••••", text: $password)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(OverlayTheme.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius))
                            .overlay(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius).stroke(OverlayTheme.border))
                            .foregroundStyle(OverlayTheme.textPrimary)
                    }
                    }
                    .padding(.horizontal, 24)
                }

                // Success message
                if authManager.isAuthenticated {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(OverlayTheme.success)

                        Text("Account Created!")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("You're all set. The app will close this window.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }

                // Error message
                if let error = authManager.errorMessage, !authManager.isAuthenticated {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Action buttons (hide when authenticated)
                if !authManager.isAuthenticated {
                    VStack(spacing: 12) {
                        // Primary button
                        Button {
                            Task {
                                if isSignUp {
                                    await authManager.signUp(email: email, password: password)
                                } else {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                OverlayTheme.accent
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Toggle sign in/sign up (hide if authenticated)
                if !authManager.isAuthenticated {
                    VStack(spacing: 12) {
                        Button {
                            isSignUp.toggle()
                            authManager.errorMessage = nil
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.caption)
                                .foregroundStyle(OverlayTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)
                } else {
                    // Close button when authenticated
                    Button {
                        // Close the login window
                        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "login" }) {
                            window.close()
                        }
                    } label: {
                        Text("Close")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
#endif
