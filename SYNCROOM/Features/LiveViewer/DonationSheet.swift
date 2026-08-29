//  DonationSheet.swift  (S24)
//
//  Liquid Glass: a sheet *is* the platform's glass, so this file paints no
//  background of its own and never restyles the presentation — it only declares
//  `.presentationDetents([.medium, .large])` so the detents travel with the view.
//  Everything inside is content and therefore opaque: the amount tiles, the live
//  chat preview and the payment line all sit on the ink and surface ramps.
//
//  No card details are collected anywhere here. The payment line shows a method
//  the account already holds, masked to its last four digits, and nothing else.

import SwiftUI

// MARK: - Amount

/// One tile in the amount grid.
enum DonationSheetAmount: Hashable, Identifiable, Sendable {
    case preset(Int)
    /// The tile that opens the free-entry field.
    case custom

    var id: String {
        switch self {
        case .preset(let won): "preset-\(won)"
        case .custom: "custom"
        }
    }
}

/// Where a payment ended up.
enum DonationSheetOutcome: Hashable, Sendable {
    case succeeded
    case failed
}

// MARK: - Model

@MainActor
@Observable
final class DonationModel {

    /// The grid, in order: five presets and the free-entry tile.
    static let amounts: [DonationSheetAmount] = [
        .preset(1_000), .preset(5_000), .preset(10_000),
        .preset(30_000), .preset(50_000), .custom,
    ]

    /// A free-entry amount is capped at seven digits, so the field cannot be
    /// filled with a number no card would ever clear.
    static let customDigitLimit = 7

    /// A donation message rides in the chat log, so it is a note, not an essay.
    static let messageLimit = 40

    private let dataSource: any DataSource

    /// The saved methods the account already holds. Nothing here is entered.
    var methods: LoadState<[PaymentMethod]> = .loading
    var selectedMethodID: UUID?

    var selection: DonationSheetAmount
    var customAmountText: String
    var message: String

    var isSending = false
    /// `nil` while the form is still open.
    var outcome: DonationSheetOutcome?

    init(dataSource: any DataSource = MockDataSource.shared,
         selection: DonationSheetAmount = .preset(10_000),
         customAmountText: String = "",
         message: String = "",
         outcome: DonationSheetOutcome? = nil) {
        self.dataSource = dataSource
        self.selection = selection
        self.customAmountText = customAmountText
        self.message = message
        self.outcome = outcome
    }

    /// The method the donation will go out on: the chosen one, else the first.
    var method: PaymentMethod? {
        guard let methods = methods.value else { return nil }
        return methods.first { $0.id == selectedMethodID } ?? methods.first
    }

    /// The amount the button, the preview and the emphasis tier all read.
    /// `nil` while 직접 입력 is selected and still empty.
    var amount: Int? {
        switch selection {
        case .preset(let won):
            return won
        case .custom:
            let won = Int(customAmountText) ?? 0
            return won > 0 ? won : nil
        }
    }

    /// Emphasis is derived from the amount by `Donation`, never chosen here.
    var donation: Donation? {
        amount.map { Donation(amount: $0) }
    }

    var canSend: Bool { amount != nil && method != nil && !isSending }

    func load() async {
        methods = await LoadState.load { try await self.dataSource.paymentMethods() }
    }

    func select(_ amount: DonationSheetAmount) {
        selection = amount
        // A fresh choice clears a decline that belonged to the previous one.
        outcome = nil
    }

    /// Digits only, clamped at the cap as it is typed rather than rejected after
    /// the fact.
    func setCustomAmount(_ text: String) {
        let digits = text.filter { $0.isASCII && $0.isNumber }
        customAmountText = String(digits.prefix(Self.customDigitLimit))
    }

    func setMessage(_ text: String) {
        message = String(text.prefix(Self.messageLimit))
    }

    /// Runs the payment. The mock always clears — the declined state is reached
    /// by injecting `outcome: .failed`, which is what the failure preview does
    /// and what `다시 시도` recovers from.
    func send() async {
        guard canSend else { return }
        isSending = true
        outcome = nil
        try? await Task.sleep(for: .milliseconds(600))
        isSending = false
        guard !Task.isCancelled else { return }
        outcome = .succeeded
    }
}

// MARK: - Screen

struct DonationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionModel.self) private var session

    /// Grid tiles scale with Dynamic Type, so the column count falls to one at
    /// accessibility sizes instead of squeezing the amounts.
    @ScaledMetric(relativeTo: .body) private var tileMinWidth: CGFloat = Space.s96

    let room: LiveRoom
    private let onComplete: (Donation) -> Void

    @State private var model: DonationModel
    @State private var isChoosingMethod = false

    init(room: LiveRoom, onComplete: @escaping (Donation) -> Void = { _ in }) {
        self.init(room: room, model: DonationModel(), onComplete: onComplete)
    }

    /// The injection seam previews use to pick a state and a `MockDataSource`.
    init(room: LiveRoom, model: DonationModel, onComplete: @escaping (Donation) -> Void) {
        self.room = room
        self.onComplete = onComplete
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s32) {
                header

                if model.outcome == .succeeded {
                    sentContent
                } else {
                    formContent
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .motion(value: model.outcome)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await model.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text("후원하기")
                .typography(.screenTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: room.title)
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: Space.s32) {
            if model.outcome == .failed {
                InlineBanner(kind: .error,
                             message: "결제에 실패했어요",
                             actionTitle: "다시 시도") {
                    Task { await send() }
                }
            }

            amountSection
            previewSection
            messageSection
            paymentSection
            sendButton
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            LiveSheetLabel(title: "후원 금액")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: Space.s12)],
                      spacing: Space.s12) {
                ForEach(DonationModel.amounts) { amount in
                    tile(amount)
                }
            }

            if model.selection == .custom {
                customAmountField
            }
        }
        .motion(value: model.selection)
    }

    /// The chosen tile takes the ink fill, the rest stay on `surfaceRaised` —
    /// the same selected / unselected pairing every chip in the app uses.
    private func tile(_ amount: DonationSheetAmount) -> some View {
        let isSelected = model.selection == amount
        return Button {
            model.select(amount)
        } label: {
            switch amount {
            case .preset(let won):
                Text(Format.currency(won)).lineLimit(1)
            case .custom:
                Text("직접 입력").lineLimit(1)
            }
        }
        .buttonStyle(SyncFilledButtonStyle(isProminent: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Free entry. The unit sits beside the field so the field itself holds
    /// nothing but the number.
    private var customAmountField: some View {
        HStack(spacing: Space.s8) {
            TextField("직접 입력",
                      text: customAmountBinding,
                      prompt: Text("후원할 금액"))
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .typography(.rowTitle)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("원")
                .typography(.rowTitle)
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(Space.s16)
        .frame(minHeight: Metric.controlM)
        .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))
    }

    private var customAmountBinding: Binding<String> {
        Binding(
            get: { model.customAmountText },
            set: { model.setCustomAmount($0) }
        )
    }

    // MARK: - Live preview

    /// The message exactly as it will land in the chat log. Emphasis is derived
    /// from the amount, so raising the amount visibly escalates the row — which
    /// is the thing the donor is actually choosing between.
    @ViewBuilder
    private var previewSection: some View {
        if let donation = model.donation {
            VStack(alignment: .leading, spacing: Space.s12) {
                LiveSheetLabel(title: "미리보기")
                DonationMessageRow(message: previewMessage(donation))
            }
            .motion(value: donation.amount)
        }
    }

    private func previewMessage(_ donation: Donation) -> ChatMessage {
        ChatMessage(authorHandle: session.currentUser.handle,
                    authorAvatarURL: session.currentUser.avatarURL,
                    text: model.message.trimmingCharacters(in: .whitespacesAndNewlines),
                    donation: donation)
    }

    // MARK: - Message

    private var messageSection: some View {
        VStack(alignment: .trailing, spacing: Space.s8) {
            LiveSheetLabel(title: "후원 메시지")
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("후원 메시지",
                      text: messageBinding,
                      prompt: Text("응원 메시지를 남겨보세요"),
                      axis: .vertical)
                .textFieldStyle(.plain)
                .typography(.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(2...4)
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.surface))

            Text(verbatim: "\(model.message.count)/\(DonationModel.messageLimit)")
                .typography(.meta)
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityLabel("입력한 글자 수")
                .accessibilityValue(Text("\(DonationModel.messageLimit)자 중 \(model.message.count)자"))
        }
    }

    private var messageBinding: Binding<String> {
        Binding(
            get: { model.message },
            set: { model.setMessage($0) }
        )
    }

    // MARK: - Payment

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            LiveSheetLabel(title: "결제 수단",
                           actionTitle: model.methods.value?.isEmpty == false ? "변경" : nil) {
                isChoosingMethod = true
            }

            switch model.methods {
            case .loading:
                Text("불러오는 중")
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .skeleton(true)
            case .failed:
                InlineBanner(kind: .caution,
                             message: "결제 수단을 불러오지 못했어요",
                             actionTitle: "다시 시도") {
                    Task { await model.load() }
                }
            case .loaded:
                if let method = model.method {
                    Text(verbatim: Self.masked(method))
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .accessibilityLabel("결제 수단")
                        .accessibilityValue(Text("\(method.brand) 끝자리 \(method.last4)"))
                } else {
                    Text("등록된 결제 수단이 없어요")
                        .typography(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog("결제 수단", isPresented: $isChoosingMethod, titleVisibility: .visible) {
            // Card brands are account data, not copy, so they are not localized.
            ForEach(model.methods.value ?? []) { method in
                Button(Self.masked(method)) { model.selectedMethodID = method.id }
            }
            Button("취소", role: .cancel) {}
        }
    }

    /// `신한카드 ····4417`. The account holds a brand and four digits, and this
    /// is the whole of what the app ever knows or shows about a card.
    private static func masked(_ method: PaymentMethod) -> String {
        method.brand + " ····" + method.last4
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            Task { await send() }
        } label: {
            if model.isSending {
                Text("보내는 중")
            } else if let amount = model.amount {
                Text("\(Format.currency(amount)) 후원하기")
            } else {
                Text("후원하기")
            }
        }
        .buttonStyle(.syncSolid)
        .disabled(!model.canSend)
    }

    /// Runs the payment, then hands the donation back and closes. The
    /// confirmation stays up for a beat first, so the donor sees what landed
    /// before the sheet goes away.
    private func send() async {
        await model.send()
        guard model.outcome == .succeeded, let donation = model.donation else { return }
        try? await Task.sleep(for: .seconds(1.2))
        guard !Task.isCancelled else { return }
        onComplete(donation)
        dismiss()
    }

    // MARK: - Sent

    private var sentContent: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            InlineBanner(kind: .success, message: "후원을 보냈어요")

            if let donation = model.donation {
                DonationMessageRow(message: previewMessage(donation))
            }
        }
    }
}

// MARK: - Previews

private func previewDonation(_ behaviour: MockDataSource.Behaviour = .populated,
                             selection: DonationSheetAmount = .preset(10_000),
                             customAmountText: String = "",
                             message: String = "",
                             outcome: DonationSheetOutcome? = nil) -> some View {
    DonationSheet(
        room: Fixtures.chansRoom,
        model: DonationModel(dataSource: MockDataSource(behaviour: behaviour),
                             selection: selection,
                             customAmountText: customAmountText,
                             message: message,
                             outcome: outcome)
    ) { _ in }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewDonation(message: "안녕하세요").preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewDonation(message: "안녕하세요").preferredColorScheme(.dark)
}

#Preview("1,000원 — 기본 강조") {
    previewDonation(selection: .preset(1_000), message: "화이팅!")
}

#Preview("5,000원 — 중간 강조") {
    previewDonation(selection: .preset(5_000), message: "잘 듣고 있어요")
}

#Preview("직접 입력") {
    previewDonation(selection: .custom, customAmountText: "70000", message: "오늘 최고였어요")
}

#Preview("직접 입력 — 금액 없음") {
    previewDonation(selection: .custom)
}

#Preview("후원 완료") {
    previewDonation(message: "안녕하세요", outcome: .succeeded)
}

#Preview("결제 실패") {
    previewDonation(message: "안녕하세요", outcome: .failed)
}

#Preview("로딩") {
    previewDonation(.loading)
}

#Preview("결제 수단 없음") {
    previewDonation(.empty)
}

#Preview("결제 수단 오류") {
    previewDonation(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewDonation(message: "안녕하세요").environment(\.dynamicTypeSize, .accessibility3)
}
