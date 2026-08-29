//  Formatters.swift
//  One place for every number, count, amount and duration the app prints, so
//  the same value never appears in two shapes on two screens.
//
//  All user-visible text goes through `String(localized:)`, which puts it in the
//  String Catalog rather than in the binary as a hardcoded literal.

import Foundation

enum Format {

    // MARK: - Counts

    /// Counts below 10,000 are grouped (`8,304`); at or above, they collapse to
    /// the Korean ten-thousand unit (`12만`, `120만`). Values of 억 scale collapse
    /// again, so a follower count never runs off the end of a line.
    static func count(_ value: Int) -> String {
        guard value >= 10_000 else { return grouped(value) }
        if value >= 100_000_000 {
            return String(localized: "\(shortened(Double(value) / 100_000_000))억",
                          comment: "Count abbreviated to hundred-millions, e.g. 1.2억")
        }
        return String(localized: "\(shortened(Double(value) / 10_000))만",
                      comment: "Count abbreviated to ten-thousands, e.g. 12만")
    }

    /// Plain grouped digits: `8,304`.
    static func grouped(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Keeps one decimal below 10 (`1.5`) and drops it above (`12`), so the
    /// abbreviation stays short without throwing away meaningful precision.
    private static func shortened(_ value: Double) -> String {
        value >= 10
            ? String(Int(value))
            : value.formatted(.number.precision(.fractionLength(0...1)))
    }

    // MARK: - Money

    /// `10,000원`.
    static func currency(_ won: Int) -> String {
        String(localized: "\(grouped(won))원", comment: "An amount in Korean won")
    }

    // MARK: - Identity

    /// Hashtags are stored bare; the `#` is a presentation detail.
    static func hashtag(_ tag: String) -> String { "#" + tag }

    /// Handles are stored bare; the `@` is a presentation detail.
    static func handle(_ handle: String) -> String { "@" + handle }

    // MARK: - Room metadata

    /// `1명 참여중 · 8,304명 시청중`.
    ///
    /// This is the plain-text form, used for accessibility labels. On screen the
    /// same line is drawn by `RoomMetaLabel`, which emphasises the figures.
    static func roomMeta(participants: Int, viewers: Int) -> String {
        String(localized: "\(count(participants))명 참여중 · \(count(viewers))명 시청중",
               comment: "Live room metadata: participant count and viewer count")
    }

    /// `라이브 128개` — the volume behind a hashtag.
    static func liveCount(_ value: Int) -> String {
        String(localized: "라이브 \(count(value))개", comment: "Number of live rooms for a hashtag")
    }

    /// `라이브 128개 · 아티스트 2,341명` — the hashtag detail summary.
    static func hashtagSummary(liveCount lives: Int, artistCount artists: Int) -> String {
        String(localized: "라이브 \(count(lives))개 · 아티스트 \(count(artists))명",
               comment: "Hashtag detail summary line")
    }

    // MARK: - Time

    /// Elapsed broadcast time as `01:24:07`.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// How long ago something happened, e.g. `3분 전`. Locale-aware.
    static func relative(_ date: Date, now: Date = .now) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }

    /// `12,940 · 2026. 8. 27.` — the meta line under an archived broadcast.
    static func broadcastMeta(viewCount: Int, endedAt: Date) -> String {
        String(localized: "\(count(viewCount)) · \(day(endedAt))",
               comment: "Past broadcast metadata: view count and date")
    }

    /// A calendar date for archived broadcasts.
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }
}
