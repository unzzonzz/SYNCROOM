//  SessionModel.swift
//  Who is signed in, and how far through onboarding they are.
//
//  The app opens signed in, on the home screen, the way a returning user would
//  find it. The sign-in and onboarding screens are reached by signing out from
//  Settings, which is the only route a real user has to them too.

import Observation

@MainActor
@Observable
final class SessionModel {

    enum Stage: Sendable {
        case signedOut          // S5
        case signUp             // S6
        case profileSetup       // S7
        case followSuggestions  // S8
        case signedIn
    }

    var stage: Stage = .signedIn
    var currentUser: Artist = Fixtures.seungchan
    var unreadNotifications: Int = Fixtures.notifications.filter { !$0.isRead }.count

    var isSignedIn: Bool { stage == .signedIn }

    func signOut() {
        stage = .signedOut
    }

    /// A social provider skips straight past the email and profile steps.
    func signInWithProvider() {
        stage = .followSuggestions
    }

    func markAllNotificationsRead() {
        unreadNotifications = 0
    }
}
