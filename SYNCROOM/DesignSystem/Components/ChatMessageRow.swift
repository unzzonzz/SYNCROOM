//  ChatMessageRow.swift
//  Live chat, in its ordinary and donation forms.
//
//  Donations escalate through three tiers of *fill*, not three different hues —
//  the app has one accent, and the largest donations are what it is for.

import SwiftUI

/// Handle and message as one wrapping paragraph, so a long message flows under
/// the handle instead of pushing it off the row.
private struct ChatText: View {
    let message: ChatMessage
    let handleColor: Color
    let bodyColor: Color

    var body: some View {
        Text(paragraph)
            .typography(.chatMessage)
            .foregroundStyle(bodyColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One attributed run so a long message wraps underneath the handle instead
    /// of pushing it out of the row. The handle is emphasised by intent rather
    /// than by a fixed font, so it stays bold at every Dynamic Type size.
    private var paragraph: AttributedString {
        var handle = AttributedString(Format.handle(message.authorHandle))
        handle.inlinePresentationIntent = .stronglyEmphasized
        handle.foregroundColor = handleColor

        let body = AttributedString("  " + message.text)
        return handle + body
    }
}

struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            AvatarView(identity: message.authorHandle, url: message.authorAvatarURL, size: Metric.avatarS)
            ChatText(message: message,
                     handleColor: Palette.inkSecondary,
                     bodyColor: Palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Format.handle(message.authorHandle) + " " + message.text))
    }
}

struct DonationMessageRow: View {
    let message: ChatMessage

    private var donation: Donation { message.donation ?? Donation(amount: 0) }
    private var isHeadline: Bool { donation.emphasis == .headline }
    private var inset: CGFloat { donation.emphasis == .standard ? 0 : Space.s12 }

    var body: some View {
        HStack(alignment: .center, spacing: Space.s12) {
            AvatarView(identity: message.authorHandle, url: message.authorAvatarURL, size: Metric.avatarS)
                // On the accent fill the avatar needs its own ground to stay a
                // distinct shape.
                .background(isHeadline ? Palette.surface : .clear, in: .circle)

            ChatText(message: message,
                     handleColor: isHeadline ? Palette.onSignal : Palette.inkSecondary,
                     bodyColor: isHeadline ? Palette.onSignal : Palette.ink)

            AmountBadge(amount: donation.amount)
        }
        .padding(.horizontal, inset)
        .padding(.vertical, inset)
        .background {
            switch donation.emphasis {
            case .standard:
                Color.clear
            case .raised:
                RoundedRectangle(cornerRadius: Radius.panel).fill(Palette.surfaceRaised)
            case .headline:
                RoundedRectangle(cornerRadius: Radius.panel).fill(Palette.signalLive)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Format.handle(message.authorHandle) + " " + message.text))
        .accessibilityValue(Text(Format.currency(donation.amount)))
    }
}

/// The amount that came with a donation. Ink-filled in every tier — it is the
/// number that matters, and it must stay readable on the accent fill too.
struct AmountBadge: View {
    let amount: Int

    var body: some View {
        Text(Format.currency(amount))
            .typography(.chip)
            .foregroundStyle(Palette.surface)
            .lineLimit(1)
            .padding(.horizontal, Space.s8)
            .frame(height: 22)
            .background(Palette.ink, in: .rect(cornerRadius: Radius.pill(22)))
    }
}

/// Renders whichever form the message calls for.
struct ChatRow: View {
    let message: ChatMessage

    var body: some View {
        if message.donation == nil {
            ChatMessageRow(message: message)
        } else {
            DonationMessageRow(message: message)
        }
    }
}

#Preview("Chat log") {
    VStack(alignment: .leading, spacing: Space.s16) {
        ForEach(Fixtures.chatLog) { ChatRow(message: $0) }
    }
    .padding(Metric.screenMargin)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surface)
}

#Preview("Donation tiers", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        ForEach(Fixtures.donationTiers) { DonationMessageRow(message: $0) }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
