//
//  LoginView.swift
//  RepoWhisper
//
//  Supabase authentication login view.
//

import SwiftUI
import Supabase

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Logo and title
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("RepoWhisper")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Voice-powered code search")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Form fields
                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        SecureField("••••••••", text: $password)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                
                // Success message
                if authManager.isAuthenticated {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
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
                
                // Action buttons
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
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || authManager.isAuthenticated)
                    
                    // GitHub OAuth (optional - only show if enabled)
                    // Note: GitHub OAuth must be enabled in Supabase dashboard
                    // For now, we'll hide it and users can use email/password
                    /*
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    
                    // GitHub OAuth
                    Button {
                        Task {
                            await authManager.signInWithOAuth(provider: .github)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("Continue with GitHub")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(authManager.isLoading)
                    */
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Toggle sign in/sign up (hide if authenticated)
                if !authManager.isAuthenticated {
                    Button {
                        isSignUp.toggle()
                        authManager.errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
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

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}

