//
//  SWUserManager.swift
//  ShipSwift
//
//  Local demo authentication manager used by the showcase app.
//  Replaces remote Amplify/Cognito calls with lightweight on-device state
//  so the sample project can run without external Swift packages.
//

import Foundation
import SwiftUI
import StoreKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Session State

enum SWSessionState: Equatable {
    case loading
    case signedOut(errorMessage: String? = nil)
    case guest
    case onboarding(tokens: SWAuthTokens)
    case ready(tokens: SWAuthTokens)

    var isSignedIn: Bool {
        switch self {
        case .onboarding, .ready: return true
        case .signedOut, .loading, .guest: return false
        }
    }

    var isGuest: Bool {
        if case .guest = self { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var tokens: SWAuthTokens? {
        switch self {
        case .onboarding(let tokens), .ready(let tokens): return tokens
        case .signedOut, .loading, .guest: return nil
        }
    }

    var errorMessage: String? {
        if case .signedOut(let message) = self { return message }
        return nil
    }
}

// MARK: - Auth Tokens

struct SWAuthTokens: Equatable {
    let idToken: String
    let accessToken: String
    let refreshToken: String
}

// MARK: - Service Error

enum SWServiceError: LocalizedError {
    case notSignedIn
    case tokenMissing
    case invalidURL
    case networkError
    case unauthorized
    case serverError(Int)
    case timeout
    case userProfileNotFound
    case userAlreadyExists
    case validationError(String)
    case decodingError
    case encodingError
    case invalidResponse
    case invalidState
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in"
        case .tokenMissing: return "Session expired, please sign in again"
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network connection failed"
        case .unauthorized: return "Session expired, please sign in again"
        case .serverError(let code): return "Server error (\(code))"
        case .timeout: return "Request timeout, please retry"
        case .userProfileNotFound: return "User profile not found"
        case .userAlreadyExists: return "User profile already exists"
        case .validationError(let message): return "Validation failed: \(message)"
        case .decodingError: return "Data parsing error"
        case .encodingError: return "Data encoding error"
        case .invalidResponse: return "Invalid response"
        case .invalidState: return "Invalid state"
        case .unknown(let message): return message
        }
    }
}

// MARK: - User Manager

@MainActor
@Observable
final class SWUserManager {

    private enum StorageKey: String {
        case isFirstLaunch
        case appLaunchCount
        case actionCompletedCount
        case lastReviewRequestDate
        case hasRequestedReview
        case currentEmail
        case currentTokens
        case registeredUsers
        case pendingSignUpEmail
        case pendingSignUpPassword
        case pendingResetEmail
        case pendingPhoneNumber
    }

    private enum ReviewConfig {
        static let minActions = 2
        static let minLaunches = 3
        static let daysBetweenRequests = 30
        static let delayBeforeRequest: Duration = .seconds(1)
    }

    private let skipAuthCheck: Bool
    private let verificationCode = "123456"

    var sessionState: SWSessionState = .loading
    var isAuthenticating = false

    var isFirstLaunch: Bool = false {
        didSet {
            UserDefaults.standard.set(!isFirstLaunch, forKey: StorageKey.isFirstLaunch.rawValue)
        }
    }

    private var actionCompletedCount: Int {
        get { UserDefaults.standard.integer(forKey: StorageKey.actionCompletedCount.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.actionCompletedCount.rawValue) }
    }

    private var appLaunchCount: Int {
        get { UserDefaults.standard.integer(forKey: StorageKey.appLaunchCount.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.appLaunchCount.rawValue) }
    }

    private var hasRequestedReview: Bool {
        get { UserDefaults.standard.bool(forKey: StorageKey.hasRequestedReview.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.hasRequestedReview.rawValue) }
    }

    private var lastReviewRequestDate: Date? {
        get { UserDefaults.standard.object(forKey: StorageKey.lastReviewRequestDate.rawValue) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.lastReviewRequestDate.rawValue) }
    }

    init(skipAuthCheck: Bool = false) {
        self.skipAuthCheck = skipAuthCheck
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: StorageKey.isFirstLaunch.rawValue)
        appLaunchCount += 1

        if skipAuthCheck {
            sessionState = .signedOut()
        } else {
            Task {
                await checkAuthStatus()
            }
        }
    }

    func completeFirstLaunch() {
        isFirstLaunch = false
    }

    func checkAuthStatus() async {
        sessionState = .loading

        if let tokens = storedTokens() {
            sessionState = .ready(tokens: tokens)
        } else {
            sessionState = .signedOut()
        }
    }

    func signUp(email: String, password: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        var users = registeredUsers()
        if users[email] != nil {
            throw SWServiceError.userAlreadyExists
        }

        // Store a pending sign-up so the demo can still exercise verification flow.
        UserDefaults.standard.set(email, forKey: StorageKey.pendingSignUpEmail.rawValue)
        UserDefaults.standard.set(password, forKey: StorageKey.pendingSignUpPassword.rawValue)
    }

    func confirmSignUp(email: String, code: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        guard code == verificationCode else {
            throw SWServiceError.validationError("Verification code should be \(verificationCode)")
        }

        guard
            let pendingEmail = UserDefaults.standard.string(forKey: StorageKey.pendingSignUpEmail.rawValue),
            let pendingPassword = UserDefaults.standard.string(forKey: StorageKey.pendingSignUpPassword.rawValue),
            pendingEmail == email
        else {
            throw SWServiceError.invalidState
        }

        var users = registeredUsers()
        users[email] = pendingPassword
        saveRegisteredUsers(users)

        UserDefaults.standard.removeObject(forKey: StorageKey.pendingSignUpEmail.rawValue)
        UserDefaults.standard.removeObject(forKey: StorageKey.pendingSignUpPassword.rawValue)
    }

    func resendSignUpCode(email: String) async throws {
        guard UserDefaults.standard.string(forKey: StorageKey.pendingSignUpEmail.rawValue) == email else {
            throw SWServiceError.invalidState
        }
    }

    func signIn(email: String, password: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let users = registeredUsers()
        guard let storedPassword = users[email] else {
            throw SWServiceError.userProfileNotFound
        }
        guard storedPassword == password else {
            throw SWServiceError.unauthorized
        }

        let tokens = makeTokens(email: email)
        saveSession(email: email, tokens: tokens)
        sessionState = .ready(tokens: tokens)
    }

    func signInWithApple() async throws {
        try await signInWithProviderEmail("apple-demo@shipswift.app")
    }

    func signInWithGoogle() async throws {
        try await signInWithProviderEmail("google-demo@shipswift.app")
    }

    func skipSignIn() {
        clearSession()
        sessionState = .guest
    }

    func requireSignIn() {
        clearSession()
        sessionState = .signedOut()
    }

    func signOut() async {
        clearSession()
        sessionState = .signedOut()
    }

    func deleteAccount() async throws {
        guard let email = UserDefaults.standard.string(forKey: StorageKey.currentEmail.rawValue) else {
            throw SWServiceError.notSignedIn
        }

        var users = registeredUsers()
        users.removeValue(forKey: email)
        saveRegisteredUsers(users)
        clearSession()
        sessionState = .signedOut()
    }

    func sendPhoneVerificationCode(phoneNumber: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }
        UserDefaults.standard.set(phoneNumber, forKey: StorageKey.pendingPhoneNumber.rawValue)
    }

    func confirmPhoneSignIn(phoneNumber: String, code: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        guard code == verificationCode else {
            throw SWServiceError.validationError("Verification code should be \(verificationCode)")
        }
        guard UserDefaults.standard.string(forKey: StorageKey.pendingPhoneNumber.rawValue) == phoneNumber else {
            throw SWServiceError.invalidState
        }

        let email = "phone-\(sanitizedIdentifier(phoneNumber))@shipswift.app"
        let tokens = makeTokens(email: email)
        saveSession(email: email, tokens: tokens)
        sessionState = .ready(tokens: tokens)
        UserDefaults.standard.removeObject(forKey: StorageKey.pendingPhoneNumber.rawValue)
    }

    func forgotPassword(email: String) async throws {
        guard registeredUsers()[email] != nil else {
            throw SWServiceError.userProfileNotFound
        }
        UserDefaults.standard.set(email, forKey: StorageKey.pendingResetEmail.rawValue)
    }

    func confirmResetPassword(email: String, newPassword: String, code: String) async throws {
        guard code == verificationCode else {
            throw SWServiceError.validationError("Verification code should be \(verificationCode)")
        }
        guard UserDefaults.standard.string(forKey: StorageKey.pendingResetEmail.rawValue) == email else {
            throw SWServiceError.invalidState
        }

        var users = registeredUsers()
        guard users[email] != nil else {
            throw SWServiceError.userProfileNotFound
        }
        users[email] = newPassword
        saveRegisteredUsers(users)
        UserDefaults.standard.removeObject(forKey: StorageKey.pendingResetEmail.rawValue)
    }

    func completeOnboarding() {
        guard let tokens = sessionState.tokens else { return }
        sessionState = .ready(tokens: tokens)
    }

    func getFreshIdToken() async -> String? {
        guard sessionState.isSignedIn else { return nil }
        return storedTokens()?.idToken
    }

    func refreshSession() async throws {
        guard let email = UserDefaults.standard.string(forKey: StorageKey.currentEmail.rawValue) else {
            throw SWServiceError.tokenMissing
        }

        let tokens = makeTokens(email: email)
        saveSession(email: email, tokens: tokens)

        switch sessionState {
        case .onboarding:
            sessionState = .onboarding(tokens: tokens)
        case .ready:
            sessionState = .ready(tokens: tokens)
        default:
            sessionState = .ready(tokens: tokens)
        }
    }

    func incrementActionCompletedCount() {
        actionCompletedCount += 1
        requestReviewIfAppropriate()
    }

    func recordPositiveUserAction() {
        requestReviewIfAppropriate()
    }

    private func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }

        Task {
            try? await Task.sleep(for: ReviewConfig.delayBeforeRequest)
            await requestReview()
        }
    }

    private func shouldRequestReview() -> Bool {
        if hasRequestedReview, let lastDate = lastReviewRequestDate {
            let daysSinceLastRequest = Calendar.current.dateComponents(
                [.day],
                from: lastDate,
                to: .now
            ).day ?? 0

            guard daysSinceLastRequest >= ReviewConfig.daysBetweenRequests else {
                return false
            }
        }

        return actionCompletedCount >= ReviewConfig.minActions
            && appLaunchCount >= ReviewConfig.minLaunches
    }

    private func requestReview() async {
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        AppStore.requestReview(in: scene)
        #endif

        hasRequestedReview = true
        lastReviewRequestDate = .now
    }

    private func signInWithProviderEmail(_ email: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        var users = registeredUsers()
        if users[email] == nil {
            users[email] = "provider-login"
            saveRegisteredUsers(users)
        }

        let tokens = makeTokens(email: email)
        saveSession(email: email, tokens: tokens)
        sessionState = .ready(tokens: tokens)
    }

    private func registeredUsers() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: StorageKey.registeredUsers.rawValue) as? [String: String] ?? [:]
    }

    private func saveRegisteredUsers(_ users: [String: String]) {
        UserDefaults.standard.set(users, forKey: StorageKey.registeredUsers.rawValue)
    }

    private func saveSession(email: String, tokens: SWAuthTokens) {
        UserDefaults.standard.set(email, forKey: StorageKey.currentEmail.rawValue)
        UserDefaults.standard.set(
            [
                "idToken": tokens.idToken,
                "accessToken": tokens.accessToken,
                "refreshToken": tokens.refreshToken
            ],
            forKey: StorageKey.currentTokens.rawValue
        )
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: StorageKey.currentEmail.rawValue)
        UserDefaults.standard.removeObject(forKey: StorageKey.currentTokens.rawValue)
    }

    private func storedTokens() -> SWAuthTokens? {
        guard
            let dictionary = UserDefaults.standard.dictionary(forKey: StorageKey.currentTokens.rawValue),
            let idToken = dictionary["idToken"] as? String,
            let accessToken = dictionary["accessToken"] as? String,
            let refreshToken = dictionary["refreshToken"] as? String
        else {
            return nil
        }

        return SWAuthTokens(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    // Create a JWT-like token so the existing settings page can still decode `email`.
    private func makeTokens(email: String) -> SWAuthTokens {
        let idToken = makeJWT(email: email, kind: "id")
        return SWAuthTokens(
            idToken: idToken,
            accessToken: makeJWT(email: email, kind: "access"),
            refreshToken: "refresh-\(sanitizedIdentifier(email))"
        )
    }

    private func makeJWT(email: String, kind: String) -> String {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = #"{"email":"\#(email)","kind":"\#(kind)"}"#
        return "\(base64(header)).\(base64(payload)).demo-signature"
    }

    private func base64(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }

    private func sanitizedIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
    }
}
