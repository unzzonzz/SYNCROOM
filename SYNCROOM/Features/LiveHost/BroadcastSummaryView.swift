//  BroadcastSummaryView.swift  (S13)
//
//  Liquid Glass: none of its own, deliberately. This screen is the last step of
//  the host flow's `.fullScreenCover`, and that presentation is the system glass
//  here — it also owns the whole display, which is why there is no toolbar and
//  the headline is the screen's title. Everything below the headline is content:
//  figures, one switch and two actions, all opaque.

import SwiftUI

// MARK: - Metrics

/// One value-over-label pair in the summary grid. The value arrives already
/// formatted — every figure on this screen goes through `Format`, including the
/// ones that abbreviate, so no two numbers are printed in two different shapes.
private struct BroadcastSummaryMetric: Identifiable {
    let id: String
    let label: LocalizedStringKey
    let value: String
}

// MARK: - Screen

struct BroadcastSummaryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: LiveSummary

    private let onDone: () -> Void

    @State private var savesReplay: Bool

    init(summary: LiveSummary, onDone: @escaping () -> Void) {
        self.init(summary: summary, savesReplay: true, onDone: onDone)
    }

    /// The injection seam previews use to show the screen with the replay switch
    /// already off.
    init(summary: LiveSummary, savesReplay: Bool, onDone: @escaping () -> Void) {
        self.summary = summary
        self.onDone = onDone
        _savesReplay = State(initialValue: savesReplay)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s48) {
                Text("라이브가 종료되었어요")
                    .typography(.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                metrics

                replaySwitch

                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s48)
            .padding(.bottom, Space.s48)
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
    }

    // MARK: - Metrics

    /// Airtime leads at display scale; the other five figures sit under it as a
    /// quiet two-column list. Six equal cards would be a dashboard, which this
    /// design system does not do — hierarchy comes from the type scale instead.
    private var metrics: some View {
        VStack(alignment: .leading, spacing: Space.s40) {
            BroadcastSummaryLeadStat(label: "방송 시간",
                                     value: Format.duration(summary.duration))

            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s32) {
                ForEach(secondaryMetrics) { metric in
                    BroadcastSummaryStat(metric: metric)
                }
            }
        }
    }

    /// Two columns normally, one once Dynamic Type is at an accessibility size
    /// and a pair of figures can no longer share a line.
    private var columns: [GridItem] {
        let column = GridItem(.flexible(), spacing: Space.s24, alignment: .leading)
        return dynamicTypeSize.isAccessibilitySize ? [column] : [column, column]
    }

    private var secondaryMetrics: [BroadcastSummaryMetric] {
        [
            BroadcastSummaryMetric(id: "peak",
                                   label: "최고 동시 시청",
                                   value: Format.count(summary.peakViewers)),
            BroadcastSummaryMetric(id: "total",
                                   label: "누적 시청",
                                   value: Format.count(summary.totalViewers)),
            BroadcastSummaryMetric(id: "participants",
                                   label: "참여자",
                                   value: String(localized: "\(Format.count(summary.participantCount))명",
                                                 comment: "How many performers joined the broadcast")),
            BroadcastSummaryMetric(id: "donation",
                                   label: "후원",
                                   value: Format.currency(summary.donationTotal)),
            BroadcastSummaryMetric(id: "followers",
                                   label: "신규 팔로워",
                                   // The sign is part of the figure, not language.
                                   value: "+" + Format.count(summary.newFollowers)),
        ]
    }

    // MARK: - Replay

    private var replaySwitch: some View {
        Toggle(isOn: $savesReplay) {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text("다시보기 저장")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("저장하면 프로필의 내 라이브에서 다시 볼 수 있어요.")
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(Palette.ink)
        .frame(minHeight: Metric.tapTarget)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Space.s12) {
            Button("홈으로") { onDone() }
                .buttonStyle(.syncSolid)

            // With the replay switched off there is nothing to open, so the
            // action leaves rather than sitting there disabled.
            if savesReplay {
                Button("다시보기 확인") { openReplay() }
                    .buttonStyle(.syncFilled)
            }
        }
        .motion(value: savesReplay)
    }

    /// The saved broadcast lands in 내 라이브, so that is where this goes — the
    /// destination is set first, then the host flow closes onto it.
    private func openReplay() {
        router.tab = .profile
        router.push(.myBroadcasts)
        onDone()
    }
}

// MARK: - Stats

/// The lead figure. Airtime is the first thing a host looks for, so it is the
/// one display-scale number on the screen.
private struct BroadcastSummaryLeadStat: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(verbatim: value)
                .typography(.displayStat)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label)
                .typography(.metaStrong)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(Text(verbatim: value))
    }
}

/// A secondary figure over its label. These stay on the section step of the type
/// scale so the lead stat keeps the screen's only display-scale voice.
private struct BroadcastSummaryStat: View {
    let metric: BroadcastSummaryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text(verbatim: metric.value)
                .typography(.sectionTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(metric.label)
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.label)
        .accessibilityValue(Text(verbatim: metric.value))
    }
}

// MARK: - Previews

private func previewSummary(_ summary: LiveSummary = Fixtures.liveSummary,
                            savesReplay: Bool = true) -> some View {
    BroadcastSummaryView(summary: summary, savesReplay: savesReplay) {}
        .environment(AppRouter())
        .environment(SessionModel())
        .environment(PlaybackController())
        .environment(SettingsStore())
}

/// A broadcast that ended before anyone arrived — every figure at zero.
private let emptySummary = LiveSummary(duration: 0,
                                       peakViewers: 0,
                                       totalViewers: 0,
                                       participantCount: 0,
                                       donationTotal: 0,
                                       newFollowers: 0)

/// The abbreviation edge: twelve hours on air and counts past 만.
private let hugeSummary = LiveSummary(duration: 43_215,
                                      peakViewers: 1_204_392,
                                      totalViewers: 12_400_000,
                                      participantCount: 4,
                                      donationTotal: 3_480_000,
                                      newFollowers: 21_400)

#Preview("기본 — 라이트") {
    previewSummary().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewSummary().preferredColorScheme(.dark)
}

#Preview("다시보기 저장 끔") {
    previewSummary(savesReplay: false)
}

#Preview("기록 없는 방송") {
    previewSummary(emptySummary)
}

#Preview("큰 수치") {
    previewSummary(hugeSummary)
}

#Preview("Dynamic Type — accessibility3") {
    previewSummary().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("지표", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s32) {
        BroadcastSummaryLeadStat(label: "방송 시간",
                                 value: Format.duration(Fixtures.liveSummary.duration))
        BroadcastSummaryStat(metric: BroadcastSummaryMetric(
            id: "total",
            label: "누적 시청",
            value: Format.count(Fixtures.liveSummary.totalViewers)))
        BroadcastSummaryStat(metric: BroadcastSummaryMetric(
            id: "donation",
            label: "후원",
            value: Format.currency(Fixtures.liveSummary.donationTotal)))
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
