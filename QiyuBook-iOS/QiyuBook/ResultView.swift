import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var store: EncounterStore
    @State private var record: EncounterRecord
    @State private var editSheet: EditSheet?
    @State private var showMedia = false
    @State private var isGeneratingArtwork = false
    @State private var didRequestArtwork = false

    init(record: EncounterRecord) {
        _record = State(initialValue: record)
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
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("这可能是")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editSheet) { sheet in
            EditRecordSheet(record: record, sheet: sheet) { updated in
                record = updated
                store.update(updated)
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
               let updated = store.updateArtwork(id: record.id, artworkBase64: artworkBase64) {
                record = updated
            }
        } catch {
            // Keep the original blurred image if artwork generation fails.
        }
    }
}
