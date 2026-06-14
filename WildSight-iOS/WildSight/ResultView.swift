import SwiftUI
import UIKit

struct ResultView: View {
    @EnvironmentObject private var store: EncounterStore
    @State private var record: EncounterRecord
    @State private var isSaved: Bool
    @State private var editSheet: EditSheet?
    @State private var showMedia = false
    @State private var isGeneratingArtwork = false
    @State private var didRequestArtwork = false

    init(record: EncounterRecord, isSaved: Bool = true) {
        _record = State(initialValue: record)
        _isSaved = State(initialValue: isSaved)
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground.ignoresSafeArea()

            GeometryReader { proxy in
                let contentWidth = max(proxy.size.width - 40, 0)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        EncounterArtworkStage(
                            record: record,
                            isGeneratingArtwork: isGeneratingArtwork
                        ) {
                            editSheet = .meta
                        } onPreview: {
                            showMedia = true
                        }
                        .frame(width: contentWidth, height: contentWidth * 0.75)

                        EncounterContentCard(record: record)
                            .frame(width: contentWidth, alignment: .leading)

                        if isSaved {
                            SavedIdentityHint()
                                .frame(width: contentWidth, alignment: .leading)
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, isSaved ? 20 : 112)
                }
            }
        }
        .navigationTitle("这可能是")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !isSaved {
                SaveIdentityCardBar {
                    saveIdentityCard()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .sheet(item: $editSheet) { sheet in
            EditRecordSheet(record: record, sheet: sheet) { updated in
                record = updated
                if isSaved {
                    store.update(updated)
                }
            }
        }
        .sheet(isPresented: $showMedia) {
            MediaPreviewSheet(record: record)
        }
        .task(id: record.id) {
            await generateArtworkIfNeeded()
        }
    }

    @MainActor
    private func generateArtworkIfNeeded() async {
        let artworkSourceURL = record.referenceImageURL ?? (record.mediaKind == .image ? record.mediaURL : nil)
        guard !didRequestArtwork, record.artworkBase64 == nil, artworkSourceURL != nil else { return }
        didRequestArtwork = true
        isGeneratingArtwork = true
        defer { isGeneratingArtwork = false }

        do {
            if let artworkBase64 = try await AIIdentifyClient().generateArtwork(mediaURL: artworkSourceURL, record: record),
               !artworkBase64.isEmpty {
                record.artworkBase64 = artworkBase64
                if isSaved, let updated = store.updateArtwork(id: record.id, artworkBase64: artworkBase64) {
                    record = updated
                }
            }
        } catch {
            // Keep the original blurred image if artwork generation fails.
        }
    }

    @MainActor
    private func saveIdentityCard() {
        guard !isSaved else { return }
        record = store.save(record)
        isSaved = true
        store.highlightSavedRecord(id: record.id)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct SaveIdentityCardBar: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                Text("保存这张身份证卡")
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
        .shadow(color: AppTheme.ink.opacity(0.10), radius: 16, x: 0, y: 8)
    }
}

private struct SavedIdentityHint: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppTheme.kelp)
            Text("已在「记录」中保存了你认识的新朋友。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }
}
