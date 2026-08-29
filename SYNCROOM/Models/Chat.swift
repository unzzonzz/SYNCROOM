//  Chat.swift

import Foundation

/// A donation attached to a chat message. Emphasis is *derived* from the amount
/// so the three tiers can never drift apart from the numbers they represent.
struct Donation: Hashable, Sendable {
    var amount: Int

    /// How loudly the message is drawn. Escalates by fill, not by hue — the app
    /// has one accent, and this is it.
    enum Emphasis: Hashable, Sendable {
        /// Amount badge only, on the ordinary chat row.
        case standard
        /// Raised container behind the row.
        case raised
        /// Accent-filled container. The loudest thing in the chat log.
        case headline
    }

    var emphasis: Emphasis {
        switch amount {
        case ..<5_000: .standard
        case ..<10_000: .raised
        default: .headline
        }
    }
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Stored without the leading `@`.
    var authorHandle: String
    var authorAvatarURL: URL?
    var text: String
    /// `nil` for an ordinary message.
    var donation: Donation?

    init(id: UUID = UUID(),
         authorHandle: String,
         authorAvatarURL: URL? = nil,
         text: String,
         donation: Donation? = nil) {
        self.id = id
        self.authorHandle = authorHandle
        self.authorAvatarURL = authorAvatarURL
        self.text = text
        self.donation = donation
    }
}

/// A saved card used for donations (S24).
struct PaymentMethod: Identifiable, Hashable, Sendable {
    let id: UUID
    var brand: String
    /// Last four digits only — never a full card number.
    var last4: String

    init(id: UUID = UUID(), brand: String, last4: String) {
        self.id = id
        self.brand = brand
        self.last4 = last4
    }
}

/// One entry in the donation history (S3 "후원 내역").
struct DonationRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    var counterpart: Artist
    var roomTitle: String
    var amount: Int
    var sentAt: Date
    /// `true` when the signed-in user sent it, `false` when they received it.
    var isOutgoing: Bool

    init(id: UUID = UUID(), counterpart: Artist, roomTitle: String,
         amount: Int, sentAt: Date, isOutgoing: Bool) {
        self.id = id
        self.counterpart = counterpart
        self.roomTitle = roomTitle
        self.amount = amount
        self.sentAt = sentAt
        self.isOutgoing = isOutgoing
    }
}
