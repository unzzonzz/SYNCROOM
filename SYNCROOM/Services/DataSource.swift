//  DataSource.swift
//  The seam between the UI and wherever data actually comes from.
//
//  Every screen talks to `DataSource` and nothing else, so swapping
//  `MockDataSource` for a networked implementation is a one-line change at the
//  composition root — no view or view model has to be touched.

import Foundation

// MARK: - Payloads

struct HomeFeed: Hashable, Sendable {
    var hero: [HeroSlide]
    var shelves: [HomeShelf]
}

struct ExploreFeed: Hashable, Sendable {
    var recent: [RecentQuery]
    var recommended: [Artist]
    var liveNow: [Artist]
}

struct SearchResults: Hashable, Sendable {
    var artists: [Artist]
    var rooms: [LiveRoom]
    var hashtags: [HashtagStat]

    var isEmpty: Bool { artists.isEmpty && rooms.isEmpty && hashtags.isEmpty }
}

struct HashtagDetail: Hashable, Sendable {
    var stat: HashtagStat
    var liveRooms: [LiveRoom]
    var topArtists: [Artist]
}

struct ProfileFeed: Hashable, Sendable {
    var artist: Artist
    var pastBroadcasts: [PastBroadcast]
    /// The room this artist is hosting right now, if any.
    var currentRoom: LiveRoom?
}

struct RoomDetail: Hashable, Sendable {
    var room: LiveRoom
    var chat: [ChatMessage]
    var participants: [Participant]
}

// MARK: - Errors

enum DataSourceError: LocalizedError, Hashable, Sendable {
    case offline
    case notFound

    var errorDescription: String? {
        switch self {
        case .offline: String(localized: "연결이 끊어졌어요", comment: "Network error title")
        case .notFound: String(localized: "찾을 수 없어요", comment: "Missing resource error title")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .offline: String(localized: "네트워크 상태를 확인하고 다시 시도해주세요.",
                              comment: "Network error recovery text")
        case .notFound: String(localized: "요청한 내용이 삭제되었을 수 있어요.",
                               comment: "Missing resource recovery text")
        }
    }
}

// MARK: - Protocol

@MainActor
protocol DataSource: AnyObject {

    // Discovery
    func homeFeed() async throws -> HomeFeed
    func exploreFeed() async throws -> ExploreFeed
    func search(query: String, scope: SearchScope) async throws -> SearchResults
    func suggestions(for query: String) async throws -> [RecentQuery]
    func hashtagDetail(tag: String) async throws -> HashtagDetail

    // People
    func myProfile() async throws -> ProfileFeed
    func profile(handle: String) async throws -> ProfileFeed
    func followers(of artist: Artist) async throws -> [Artist]
    func following(of artist: Artist) async throws -> [Artist]
    /// Suggested artists for the onboarding follow step.
    func onboardingSuggestions() async throws -> [Artist]

    // Rooms
    func roomDetail(id: UUID) async throws -> RoomDetail
    func joinRequests(roomID: UUID) async throws -> [JoinRequest]
    func liveSummary(roomID: UUID) async throws -> LiveSummary

    // Account
    func notifications() async throws -> [AppNotification]
    func donationHistory() async throws -> [DonationRecord]
    func watchHistory() async throws -> [LiveRoom]
    func myBroadcasts() async throws -> [PastBroadcast]
    func paymentMethods() async throws -> [PaymentMethod]

    // Devices
    func audioDevices() async throws -> [AudioDevice]
}
