//  MockDataSource.swift
//  Serves the `Fixtures` graph behind the `DataSource` protocol.
//
//  `behaviour` lets a screen — or a preview — ask for the populated, empty,
//  failing or slow version of the same API, which is how the empty / loading /
//  error states in this app are demonstrated without special-casing view code.

import Foundation

@MainActor
final class MockDataSource: DataSource {

    enum Behaviour: Sendable {
        /// Fixtures, after a short delay so skeletons are visible.
        case populated
        /// Every collection comes back empty.
        case empty
        /// Every call throws `DataSourceError.offline`.
        case failing
        /// Never finishes, so a preview can sit in its loading state.
        case loading
    }

    var behaviour: Behaviour

    /// The instance the running app uses.
    static let shared = MockDataSource()

    init(behaviour: Behaviour = .populated) {
        self.behaviour = behaviour
    }

    // MARK: - Behaviour gate

    /// Applies the configured behaviour, then returns the populated value.
    private func resolve<T>(empty: @autoclosure () -> T,
                            _ value: @autoclosure () -> T) async throws -> T {
        switch behaviour {
        case .populated:
            try await Task.sleep(for: .milliseconds(120))
            return value()
        case .empty:
            try await Task.sleep(for: .milliseconds(120))
            return empty()
        case .failing:
            try await Task.sleep(for: .milliseconds(120))
            throw DataSourceError.offline
        case .loading:
            // Suspends until the surrounding task is cancelled.
            try await Task.sleep(for: .seconds(60 * 60))
            return value()
        }
    }

    // MARK: - Discovery

    func homeFeed() async throws -> HomeFeed {
        try await resolve(
            empty: HomeFeed(hero: [], shelves: []),
            HomeFeed(hero: Fixtures.heroSlides, shelves: Fixtures.homeShelves)
        )
    }

    func exploreFeed() async throws -> ExploreFeed {
        try await resolve(
            empty: ExploreFeed(recent: [], recommended: [], liveNow: []),
            ExploreFeed(recent: Fixtures.recentQueries,
                        recommended: Fixtures.recommendedArtists,
                        liveNow: Fixtures.liveArtists)
        )
    }

    func search(query: String, scope: SearchScope) async throws -> SearchResults {
        let needle = query.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#@"))
            .lowercased()

        func matches(_ haystack: String) -> Bool {
            needle.isEmpty || haystack.lowercased().contains(needle)
        }

        let artists = Fixtures.allArtists.filter {
            matches($0.displayName) || matches($0.handle) || $0.hashtags.contains(where: matches)
        }
        let rooms = Fixtures.allRooms.filter {
            matches($0.title) || matches($0.host.displayName) || $0.hashtags.contains(where: matches)
        }
        let tags = Fixtures.hashtagStats.filter { matches($0.tag) }

        let scoped: SearchResults = switch scope {
        case .all: SearchResults(artists: artists, rooms: rooms, hashtags: tags)
        case .artist: SearchResults(artists: artists, rooms: [], hashtags: [])
        case .live: SearchResults(artists: [], rooms: rooms, hashtags: [])
        case .hashtag: SearchResults(artists: [], rooms: [], hashtags: tags)
        }

        return try await resolve(
            empty: SearchResults(artists: [], rooms: [], hashtags: []),
            scoped
        )
    }

    func suggestions(for query: String) async throws -> [RecentQuery] {
        let needle = query.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#@"))
            .lowercased()
        guard !needle.isEmpty else { return [] }

        let artists = Fixtures.allArtists
            .filter { $0.displayName.lowercased().contains(needle)
                   || $0.handle.lowercased().contains(needle) }
            .prefix(3)
            .map { RecentQuery.artist($0) }

        let tags = Fixtures.hashtagStats
            .filter { $0.tag.lowercased().contains(needle) }
            .prefix(3)
            .map { RecentQuery.hashtag($0.tag) }

        return try await resolve(empty: [], artists + tags)
    }

    func hashtagDetail(tag: String) async throws -> HashtagDetail {
        let stat = Fixtures.hashtagStats.first { $0.tag.caseInsensitiveCompare(tag) == .orderedSame }
            ?? HashtagStat(tag: tag, liveCount: 0, artistCount: 0)
        let rooms = Fixtures.allRooms.filter { room in
            room.status == .live
                && room.hashtags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
        let artists = Fixtures.allArtists.filter { artist in
            artist.hashtags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
        return try await resolve(
            empty: HashtagDetail(stat: stat, liveRooms: [], topArtists: []),
            HashtagDetail(stat: stat, liveRooms: rooms, topArtists: artists)
        )
    }

    // MARK: - People

    func myProfile() async throws -> ProfileFeed {
        try await resolve(
            empty: ProfileFeed(artist: Fixtures.seungchan, pastBroadcasts: [], currentRoom: nil),
            ProfileFeed(artist: Fixtures.seungchan,
                        pastBroadcasts: Fixtures.pastBroadcasts,
                        currentRoom: Fixtures.chansRoom)
        )
    }

    func profile(handle: String) async throws -> ProfileFeed {
        guard let artist = Fixtures.allArtists.first(where: { $0.handle == handle }) else {
            throw DataSourceError.notFound
        }
        let room = Fixtures.allRooms.first { $0.host.handle == handle && $0.status == .live }
        return try await resolve(
            empty: ProfileFeed(artist: artist, pastBroadcasts: [], currentRoom: room),
            ProfileFeed(artist: artist,
                        pastBroadcasts: artist.isVerified ? Fixtures.pastBroadcasts : [],
                        currentRoom: room)
        )
    }

    func followers(of artist: Artist) async throws -> [Artist] {
        try await resolve(empty: [],
                          [Fixtures.brightWolf, Fixtures.silentEagle, Fixtures.fastDragon,
                           Fixtures.happyPanda, Fixtures.loudLion])
    }

    func following(of artist: Artist) async throws -> [Artist] {
        try await resolve(empty: [], [Fixtures.user, Fixtures.longform])
    }

    func onboardingSuggestions() async throws -> [Artist] {
        try await resolve(empty: [],
                          [Fixtures.seungchan, Fixtures.user, Fixtures.longform,
                           Fixtures.brightWolf, Fixtures.silentEagle, Fixtures.loudLion])
    }

    // MARK: - Rooms

    func roomDetail(id: UUID) async throws -> RoomDetail {
        guard let room = Fixtures.allRooms.first(where: { $0.id == id }) else {
            throw DataSourceError.notFound
        }
        return try await resolve(
            empty: RoomDetail(room: room, chat: [], participants: []),
            RoomDetail(room: room,
                       chat: room.status == .live ? Fixtures.chatLog : [],
                       participants: room.participantCount > 0 ? Fixtures.participants : [])
        )
    }

    func joinRequests(roomID: UUID) async throws -> [JoinRequest] {
        try await resolve(empty: [], Fixtures.joinRequests)
    }

    func liveSummary(roomID: UUID) async throws -> LiveSummary {
        try await resolve(empty: Fixtures.liveSummary, Fixtures.liveSummary)
    }

    // MARK: - Account

    func notifications() async throws -> [AppNotification] {
        try await resolve(empty: [], Fixtures.notifications)
    }

    func donationHistory() async throws -> [DonationRecord] {
        try await resolve(empty: [], Fixtures.donationHistory)
    }

    func watchHistory() async throws -> [LiveRoom] {
        try await resolve(empty: [], Fixtures.watchHistory)
    }

    func myBroadcasts() async throws -> [PastBroadcast] {
        try await resolve(empty: [], Fixtures.pastBroadcasts)
    }

    func paymentMethods() async throws -> [PaymentMethod] {
        try await resolve(empty: [], Fixtures.paymentMethods)
    }

    // MARK: - Devices

    func audioDevices() async throws -> [AudioDevice] {
        try await resolve(empty: [], Fixtures.audioDevices)
    }
}
