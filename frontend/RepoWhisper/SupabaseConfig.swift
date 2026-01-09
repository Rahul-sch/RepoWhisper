//
//  SupabaseConfig.swift
//  RepoWhisper
//
//  Supabase client configuration and initialization.
//

import Foundation
import Supabase
import SupabaseAuth

/// Supabase configuration constants
enum SupabaseConfig {
    /// Supabase project URL
    static let url = URL(string: "https://kjpxpppaeydireznlzwe.supabase.co")!
    
    /// Supabase anonymous/public key
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcHhwcHBhZXlkaXJlem5sendlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MDIwNTIsImV4cCI6MjA4MzQ3ODA1Mn0.YAHTxLc8ThKtbqOtvKU2yda_eZv2q91-gUHnMX-laVc"
    
    /// Backend API URL for local development
    static let backendURL = URL(string: "http://127.0.0.1:8000")!
}

/// UserDefaults-based storage to avoid keychain prompts
final class UserDefaultsStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults = UserDefaults.standard
    
    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: key)
    }
    
    func retrieve(key: String) throws -> Data? {
        return defaults.data(forKey: key)
    }
    
    func remove(key: String) throws {
        defaults.removeObject(forKey: key)
    }
}

/// Shared Supabase client instance (using UserDefaults instead of keychain)
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(
        auth: AuthOptions(
            storage: UserDefaultsStorage()
        )
    )
)

