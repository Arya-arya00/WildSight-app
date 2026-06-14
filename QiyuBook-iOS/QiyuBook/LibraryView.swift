import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: EncounterStore
    @State private var actionRecord: EncounterRecord?

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
                                EncounterCard(
                                    record: record,
                                    isHighlighted: store.highlightedRecordID == record.id
                                )
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.45)
                                    .onEnded { _ in
                                        actionRecord = record
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                            )
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
        .confirmationDialog(
            "身份卡操作",
            isPresented: Binding(
                get: { actionRecord != nil },
                set: { isPresented in
                    if !isPresented {
                        actionRecord = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("删除此记录", role: .destructive) {
                if let id = actionRecord?.id {
                    store.delete(id: id)
                }
                actionRecord = nil
            }
            Button("取消", role: .cancel) {
                actionRecord = nil
            }
        } message: {
            if let name = actionRecord?.name {
                Text("将从「记录」中删除 \(name)。")
            }
        }
    }
}

struct EncounterCard: View {
    let record: EncounterRecord
    var isHighlighted = false

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
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isHighlighted ? AppTheme.kelp : .clear, lineWidth: 2.5)
        )
        .shadow(
            color: isHighlighted ? AppTheme.kelp.opacity(0.22) : .clear,
            radius: isHighlighted ? 16 : 0,
            x: 0,
            y: isHighlighted ? 8 : 0
        )
        .scaleEffect(isHighlighted ? 1.025 : 1)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isHighlighted)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(EncounterStore())
    }
}
