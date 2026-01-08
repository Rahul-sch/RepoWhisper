//
//  AuthManager.swift
//  RepoWhisper
//
//  Manages authentication state with Supabase Auth.
//

import Foundation
import Supabase
import Combine

/// Manages user authentication state throughout the app
@MainActor
class AuthManager: ObservableObject {
    /// Shared singleton instance
    static let shared = AuthManager()
    
    /// Current authenticated user
    @Published var currentUser: User?
    
    /// Current session (contains access token)
    @Published var session: Session?
    
    /// Whether user is authenticated
    @Published var isAuthenticated: Bool = false
    
    /// Loading state for auth operations
    @Published var isLoading: Bool = false
    
    /// Error message from last auth operation
    @Published var errorMessage: String?
    
    private var authStateTask: Task<Void, Never>?
    
    private init() {
        setupAuthStateListener()
        // Check session asynchronously without blocking
        Task { @MainActor in
            await checkExistingSession()
        }
    }
    
    /// Set up listener for auth state changes
    private func setupAuthStateListener() {
        authStateTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.session = session
                    self.currentUser = session?.user
                    self.isAuthenticated = session != nil
                    
                    switch event {
                    case .signedIn:
                        print("User signed in: \(session?.user.email ?? "unknown")")
                    case .signedOut:
                        print("User signed out")
                    case .tokenRefreshed:
                        print("Token refreshed")
                    default:
                        break
                    }
                }
            }
        }
    }
    
    /// Check for existing session on app launch
    private func checkExistingSession() async {
        do {
            // Add timeout to prevent hanging if Supabase is unreachable
            let session = try await withTimeout(seconds: 3) {
                try await supabase.auth.session
            }
            await MainActor.run {
                self.session = session
                self.currentUser = session.user
                self.isAuthenticated = true
            }
        } catch {
            // No existing session or timeout
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }
    
    /// Helper to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error {}
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            self.session = session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Sign up with email and password
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign up (emailRedirectTo is configured in Supabase dashboard)
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            if let session = response.session {
                // User is immediately signed in (if email confirmation is disabled)
                await MainActor.run {
                    self.session = session
                    self.currentUser = session.user
                    self.isAuthenticated = true
                }
            } else {
                // Email confirmation required
                await MainActor.run {
                    self.errorMessage = "Please check your email and click the confirmation link. The link will open in this app."
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    /// Sign in with OAuth provider (GitHub, Google, etc.)
    func signInWithOAuth(provider: Provider) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use a proper redirect URL that the app can handle
            let redirectURL = URL(string: "repowhisper://auth-callback")!
            try await supabase.auth.signInWithOAuth(
                provider: provider,
                redirectTo: redirectURL
            )
        } catch {
            // Provide user-friendly error message
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("not enabled") || errorDescription.contains("unsupported provider") {
                errorMessage = "GitHub OAuth is not enabled in your Supabase project. Please use email/password sign up instead, or enable GitHub OAuth in your Supabase dashboard."
            } else {
                errorMessage = "OAuth sign in failed: \(error.localizedDescription)"
            }
            print("OAuth error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Handle OAuth callback URL (also handles email confirmation links)
    func handleOAuthCallback(url: URL) async {
        print("🔐 Handling callback URL: \(url)")
        
        // Check if this is an email confirmation link or OAuth callback
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            await MainActor.run {
                self.errorMessage = "Invalid callback URL"
            }
            return
        }
        
        // Handle email confirmation tokens
        if let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           let type = components.queryItems?.first(where: { $0.name == "type" })?.value,
           type == "email" {
            // This is an email confirmation link
            print("📧 Handling email confirmation")
            do {
                let session = try await supabase.auth.verifyOTP(
                    type: .email,
                    token: token
                )
                await MainActor.run {
                    self.session = session
                    self.currentUser = session.user
                    self.isAuthenticated = true
                    self.errorMessage = nil
                }
                print("✅ Email confirmation successful")
                return
            } catch {
                await MainActor.run {
                    self.errorMessage = "Email confirmation failed: \(error.localizedDescription)"
                }
                print("❌ Email confirmation error: \(error)")
                return
            }
        }
        
        // Handle OAuth callback
        if components.queryItems?.first(where: { $0.name == "code" }) != nil {
            do {
                let session = try await supabase.auth.session(from: url)
                await MainActor.run {
                    self.session = session
                    self.currentUser = session.user
                    self.isAuthenticated = true
                    self.errorMessage = nil
                }
                print("✅ OAuth authentication successful")
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to complete OAuth sign in: \(error.localizedDescription)"
                }
                print("❌ OAuth callback error: \(error)")
            }
        } else {
            await MainActor.run {
                self.errorMessage = "Invalid callback URL format"
            }
        }
    }
    
    /// Sign out current user
    func signOut() async {
        isLoading = true
        
        do {
            try await supabase.auth.signOut()
            self.session = nil
            self.currentUser = nil
            self.isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Get the current access token for API calls
    var accessToken: String? {
        session?.accessToken
    }
    
    deinit {
        authStateTask?.cancel()
    }
}

