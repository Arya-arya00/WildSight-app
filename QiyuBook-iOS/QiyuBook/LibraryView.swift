import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var store: EncounterStore
    @State private var actionRecord: EncounterRecord?
    @State private var activeRecord: ActiveRecord?

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
                            ZStack(alignment: .top) {
                                EncounterCard(
                                    record: record,
                                    isHighlighted: store.highlightedRecordID == record.id
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .gesture(
                                    ExclusiveGesture(
                                        LongPressGesture(minimumDuration: 0.45),
                                        TapGesture()
                                    )
                                    .onEnded { value in
                                        switch value {
                                        case .first:
                                            actionRecord = record
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        case .second:
                                            activeRecord = ActiveRecord(id: record.id)
                                        }
                                    }
                                )

                                if actionRecord?.id == record.id {
                                    RecordActionPopover(record: record) {
                                        store.delete(id: record.id)
                                        actionRecord = nil
                                    } onCancel: {
                                        actionRecord = nil
                                    }
                                    .offset(y: -72)
                                    .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
                                    .zIndex(20)
                                }
                            }
                            .zIndex(actionRecord?.id == record.id ? 10 : 0)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $activeRecord) { active in
            if let record = store.record(id: active.id) {
                DetailView(record: record)
            } else {
                ContentUnavailableView("记录不存在", systemImage: "questionmark.folder")
            }
        }
    }
}

private struct RecordActionPopover: View {
    let record: EncounterRecord
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .center, spacing: 2) {
                Text("身份卡操作")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(record.name)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button(role: .destructive, action: onDelete) {
                Text("删除此记录")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))

            Button("取消", action: onCancel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 156)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            TrianglePointer()
                .fill(.regularMaterial)
                .frame(width: 22, height: 12)
                .offset(y: 11)
        }
        .shadow(color: AppTheme.ink.opacity(0.14), radius: 18, x: 0, y: 10)
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
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
