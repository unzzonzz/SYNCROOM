//  ShareProfileSheet.swift  (S16)
//
//  Liquid Glass: a sheet *is* the platform's glass, so this file paints no
//  background and never restyles the presentation — it only declares
//  `.presentationDetents([.height(280)])`, so the compact height travels with
//  the view instead of living at whichever screen presents it. The QR code
//  arrives as a second system `.sheet` on top, and the OS share sheet comes from
//  `ShareLink`; everything inside the content column stays opaque.

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct ShareProfileSheet: View {

    /// 280pt — a preview card and one row of actions, and nothing else. Written
    /// in scale steps so it moves with the spacing system.
    static let detentHeight: CGFloat = Space.s160 + Space.s120

    let artist: Artist

    @State private var toast: Toast?
    @State private var isPresentingCode = false

    /// What every action on this sheet hands out.
    private var link: URL { ShareProfileLink.url(for: artist) }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s32) {
                ShareProfileCard(artist: artist)
                actions
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Space.s24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.height(Self.detentHeight)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isPresentingCode) {
            // The code sheet owns its own detent, the same way this one does.
            ShareProfileCodeSheet(artist: artist, link: link)
        }
        .toast($toast)
    }

    // MARK: - Actions

    /// Side by side while the three labels fit; stacked once Dynamic Type makes
    /// them too wide to share a line.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s12) {
                copyButton
                codeButton
                shareButton
            }
            VStack(spacing: Space.s12) {
                copyButton
                codeButton
                shareButton
            }
        }
    }

    private var copyButton: some View {
        Button("링크 복사") {
            UIPasteboard.general.string = link.absoluteString
            toast = Toast(message: String(localized: "링크를 복사했어요",
                                          comment: "Confirmation after copying a profile link"))
        }
        .buttonStyle(.syncFilled)
    }

    private var codeButton: some View {
        Button("QR 코드") {
            isPresentingCode = true
        }
        .buttonStyle(.syncFilled)
    }

    /// The OS share sheet. `ShareLink` is the system's own control, so the
    /// destinations it offers are whatever the device actually has.
    private var shareButton: some View {
        ShareLink(item: link) {
            Text("공유")
        }
        .buttonStyle(.syncFilled)
    }
}

// MARK: - Preview card

/// What the person on the other end will see: avatar, name, handle. It carries
/// a real container because it stands for something being handed over — an
/// opaque `surfaceRaised` fill, never a translucent pane.
private struct ShareProfileCard: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: Space.s12) {
            AvatarView(artist: artist, size: Metric.avatarL)

            VStack(alignment: .leading, spacing: Space.s4) {
                NameLabel(artist: artist, style: .cardTitle)
                Text(verbatim: Format.handle(artist.handle))
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.s16)
        .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - QR code sheet

/// The three things this sheet can be showing.
private enum ShareProfileCodeState {
    case rendering
    case ready(Image)
    case unavailable
}

/// A second sheet rather than a taller first one: the share sheet is a fixed
/// compact height by design, and a scannable code needs room the 280pt detent
/// does not have.
private struct ShareProfileCodeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let artist: Artist
    let link: URL

    @State private var code: ShareProfileCodeState = .rendering

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Space.s24) {
                codeBlock

                Text(verbatim: link.absoluteString)
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Button("닫기") {
                    dismiss()
                }
                .buttonStyle(.syncFilled)
                .padding(.top, Space.s8)
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s32)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { code = ShareProfileCode.state(for: link) }
    }

    @ViewBuilder
    private var codeBlock: some View {
        switch code {
        case .rendering:
            codeFrame { Color.clear }
                .skeleton(true)

        case .ready(let image):
            codeFrame {
                image
                    // Nearest-neighbour keeps the module edges square, which is
                    // what a scanner needs.
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("프로필 QR 코드")
            .accessibilityValue(Text(verbatim: Format.handle(artist.handle)))

        case .unavailable:
            InlineBanner(kind: .caution, message: "QR 코드를 만들지 못했어요")
        }
    }

    private func codeFrame<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: Space.s160, height: Space.s160)
            .padding(Space.s16)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))
    }
}

// MARK: - Link

/// The public address of a profile: `https://syncroom.app/@unzzonzz`.
private enum ShareProfileLink {

    /// A literal that is known good at compile time, used only if a handle
    /// cannot be turned into a path.
    private static let home = URL(string: "https://syncroom.app")!

    static func url(for artist: Artist) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "syncroom.app"
        components.path = "/" + Format.handle(artist.handle)
        return components.url ?? home
    }
}

// MARK: - QR rendering

/// Rasterises the profile link into a real QR bitmap with CoreImage.
///
/// The generator emits one pixel per module, so the code is composited over a
/// white field with a four-module quiet zone and then upscaled before it is
/// rasterised. The white ground and the margin are part of what makes a QR
/// machine-readable — they are encoding, not a theme colour, which is why they
/// do not come from `Palette` and do not follow the colour scheme.
private enum ShareProfileCode {

    /// Rasterisation factor, not a layout dimension: how many bitmap pixels one
    /// QR module becomes before SwiftUI scales the image to its frame.
    private static let modulePixels: CGFloat = 12
    /// The quiet zone the QR specification asks for, in modules.
    private static let quietZoneModules: CGFloat = 4

    static func state(for url: URL) -> ShareProfileCodeState {
        guard let image = image(for: url) else { return .unavailable }
        return .ready(image)
    }

    private static func image(for url: URL) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let modules = filter.outputImage else { return nil }

        let margin = quietZoneModules
        let bounds = CGRect(x: 0,
                            y: 0,
                            width: modules.extent.width + margin * 2,
                            height: modules.extent.height + margin * 2)
        let ground = CIImage(color: .white).cropped(to: bounds)
        let placed = modules.transformed(
            by: CGAffineTransform(translationX: margin - modules.extent.minX,
                                  y: margin - modules.extent.minY)
        )
        let composed = placed
            .composited(over: ground)
            .transformed(by: CGAffineTransform(scaleX: modulePixels, y: modulePixels))

        guard let raster = CIContext().createCGImage(composed, from: composed.extent) else {
            return nil
        }
        return Image(decorative: raster, scale: 1)
    }
}

// MARK: - Previews

private func previewShare(_ artist: Artist) -> some View {
    ShareProfileSheet(artist: artist)
        .environment(AppRouter())
        .environment(SessionModel())
        .environment(PlaybackController())
        .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewShare(Fixtures.seungchan).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewShare(Fixtures.seungchan).preferredColorScheme(.dark)
}

#Preview("인증 없는 프로필") {
    previewShare(Fixtures.user)
}

#Preview("긴 이름과 핸들") {
    previewShare(Fixtures.longform)
}

#Preview("시트로 띄운 모습") {
    @Previewable @State var isPresenting = true
    Palette.surface
        .ignoresSafeArea()
        .sheet(isPresented: $isPresenting) {
            previewShare(Fixtures.seungchan)
        }
}

#Preview("QR 코드") {
    ShareProfileCodeSheet(artist: Fixtures.seungchan,
                          link: ShareProfileLink.url(for: Fixtures.seungchan))
}

#Preview("Dynamic Type — accessibility3") {
    previewShare(Fixtures.seungchan)
        .environment(\.dynamicTypeSize, .accessibility3)
}
