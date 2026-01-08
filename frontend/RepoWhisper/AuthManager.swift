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
        Task {
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
            let session = try await supabase.auth.session
            self.session = session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            // No existing session
            self.isAuthenticated = false
        }
    }
    
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
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            if let session = response.session {
                self.session = session
                self.currentUser = session.user
                self.isAuthenticated = true
            } else {
                errorMessage = "Please check your email to confirm your account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Sign in with OAuth provider (GitHub, Google, etc.)
    func signInWithOAuth(provider: Provider) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signInWithOAuth(
                provider: provider,
                redirectTo: URL(string: "repowhisper://auth-callback")
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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

