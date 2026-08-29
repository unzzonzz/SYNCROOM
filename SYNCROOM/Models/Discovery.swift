//  Discovery.swift

import Foundation

/// Search result filtering (S14).
enum SearchScope: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, artist, live, hashtag
    var id: String { rawValue }
}

/// A recent search entry. Artists and hashtags share one list and one row
/// component, so they share one type.
enum RecentQuery: Identifiable, Hashable, Sendable {
    case artist(Artist)
    case hashtag(String)

    var id: String {
        switch self {
        case .artist(let a): "artist-\(a.id.uuidString)"
        case .hashtag(let t): "hashtag-\(t)"
        }
    }

    /// The text that goes back into the search field when the row is tapped.
    var queryText: String {
        switch self {
        case .artist(let a): a.displayName
        case .hashtag(let t): Format.hashtag(t)
        }
    }
}

/// Aggregate counts behind a hashtag (S14 rows, S15 header).
struct HashtagStat: Identifiable, Hashable, Sendable {
    /// Stored without the leading `#`.
    var tag: String
    var liveCount: Int
    var artistCount: Int
    var isFollowing: Bool

    var id: String { tag }

    init(tag: String, liveCount: Int, artistCount: Int, isFollowing: Bool = false) {
        self.tag = tag
        self.liveCount = liveCount
        self.artistCount = artistCount
        self.isFollowing = isFollowing
    }
}

/// The five kinds of entry in the notification inbox (S9).
enum NotificationKind: Hashable, Sendable {
    case liveStarted
    case newFollower
    case donation
    case joinRequest
    case announcement
}

struct AppNotification: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: NotificationKind
    /// The person the notification is about. `nil` for service announcements.
    var actor: Artist?
    /// Amount, for `.donation`.
    var amount: Int?
    var receivedAt: Date
    var isRead: Bool

    init(id: UUID = UUID(),
         kind: NotificationKind,
         actor: Artist? = nil,
         amount: Int? = nil,
         receivedAt: Date,
         isRead: Bool = false) {
        self.id = id
        self.kind = kind
        self.actor = actor
        self.amount = amount
        self.receivedAt = receivedAt
        self.isRead = isRead
    }
}

/// A curated home shelf. The title is editorial and set by operations — it is
/// not derived from a hashtag.
struct HomeShelf: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var rooms: [LiveRoom]

    init(id: UUID = UUID(), title: String, rooms: [LiveRoom]) {
        self.id = id
        self.title = title
        self.rooms = rooms
    }
}

/// A hero slide on the home screen.
struct HeroSlide: Identifiable, Hashable, Sendable {
    let id: UUID
    var room: LiveRoom

    init(id: UUID = UUID(), room: LiveRoom) {
        self.id = id
        self.room = room
    }
}
