//
//  AuthManager.swift
//  RepoWhisper
//
//  Manages authentication state with JWT tokens.
//

import Foundation
import Combine

/// Manages user authentication state throughout the app
@MainActor
class AuthManager: ObservableObject {
    /// Shared singleton instance
    static let shared = AuthManager()

    /// Whether user is authenticated
    @Published var isAuthenticated: Bool = false

    /// Loading state for auth operations
    @Published var isLoading: Bool = false

    /// Error message from last auth operation
    @Published var errorMessage: String?

    /// Access token for API requests
    @Published var accessToken: String?

    private let tokenKey = "RepoWhisper.AccessToken"

    private init() {
        // Load saved token
        if let savedToken = UserDefaults.standard.string(forKey: tokenKey), !savedToken.isEmpty {
            self.accessToken = savedToken
            self.isAuthenticated = true
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Call backend auth endpoint
            let url = URL(string: "http://127.0.0.1:8000/auth/login")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["email": email, "password": password]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                self.accessToken = result.accessToken
                self.isAuthenticated = true
                UserDefaults.standard.set(result.accessToken, forKey: tokenKey)
            } else {
                let errorResult = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw AuthError.serverError(errorResult?.detail ?? "Login failed")
            }
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
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
            // Call backend auth endpoint
            let url = URL(string: "http://127.0.0.1:8000/auth/register")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["email": email, "password": password]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                self.accessToken = result.accessToken
                self.isAuthenticated = true
                UserDefaults.standard.set(result.accessToken, forKey: tokenKey)
            } else {
                let errorResult = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw AuthError.serverError(errorResult?.detail ?? "Registration failed")
            }
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Sign out current user
    func signOut() async {
        isLoading = true

        self.accessToken = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)

        isLoading = false
    }
}

// MARK: - Auth Models

struct AuthResponse: Codable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct ErrorResponse: Codable {
    let detail: String
}

enum AuthError: Error, LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}
