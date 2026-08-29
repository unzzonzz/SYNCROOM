//  AppRouter.swift
//  Navigation state: which tab is showing, what is stacked on each tab, and
//  which of the two full-screen flows is open.
//
//  Each tab keeps its own path, so switching tabs preserves where you were —
//  the behaviour a system `TabView` is expected to have.

import Observation
import SwiftUI

enum RootTab: Hashable, Sendable {
    case home, search, profile
}

/// Which side of a follow list is showing.
enum FollowScope: Hashable, Sendable {
    case followers, following
}

/// Everything reachable by a push. Sheets and full-screen covers are presented
/// state rather than path entries, so they are not listed here.
enum Route: Hashable, Sendable {
    case notifications
    case hashtag(String)
    case artist(Artist)
    case follows(FollowScope, Artist)
    case editProfile
    case settings
    case watchHistory
    case myBroadcasts
    case donationHistory
}

@MainActor
@Observable
final class AppRouter {

    var tab: RootTab = .home

    var homePath: [Route] = []
    var searchPath: [Route] = []
    var profilePath: [Route] = []

    /// The host flow (setup → audio check → broadcast → summary) runs in one
    /// full-screen cover so it can own the whole display, tab bar included.
    var isPresentingHostFlow = false

    /// Pushes onto whichever stack is currently on screen.
    func push(_ route: Route) {
        switch tab {
        case .home: homePath.append(route)
        case .search: searchPath.append(route)
        case .profile: profilePath.append(route)
        }
    }

    /// Sends the user to a hashtag from anywhere.
    func openHashtag(_ tag: String) {
        push(.hashtag(tag))
    }

    /// Sends the user to someone's profile from anywhere.
    func openArtist(_ artist: Artist) {
        push(.artist(artist))
    }

    func startHosting() {
        isPresentingHostFlow = true
    }
}
