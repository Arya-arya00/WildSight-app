import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: EncounterStore

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            AppTheme.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("每次遇见都会记录在此")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.top, 18)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.records) { record in
                            NavigationLink(value: record.id) {
                                EncounterCard(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            if let record = store.record(id: id) {
                DetailView(record: record)
            } else {
                ContentUnavailableView("记录不存在", systemImage: "questionmark.folder")
            }
        }
    }
}

struct EncounterCard: View {
    let record: EncounterRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeneratedCardArt(
                artworkBase64: record.artworkBase64,
                sourceMediaURL: record.referenceImageURL ?? record.mediaURL,
                compact: true
            )
            .aspectRatio(4.0 / 3.0, contentMode: .fit)

            VStack(alignment: .leading, spacing: 7) {
                Text(record.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text("\(record.location) · \(record.mediaKind.label)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ForEach(Array(record.tags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.kelp)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.seaGlass.opacity(0.16), in: Capsule())
                    }
                }
                .frame(height: 24, alignment: .leading)
            }
            .frame(height: 78, alignment: .top)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 18)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(EncounterStore())
    }
}
