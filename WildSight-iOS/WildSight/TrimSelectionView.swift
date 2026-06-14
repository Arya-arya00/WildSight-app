import SwiftUI
import AVKit
import UIKit

struct TrimSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let media: PickedMedia
    let onUseClip: (Double, Double) -> Void

    @State private var start: Double = 0
    @State private var player: AVPlayer?
    @State private var thumbnails: [UIImage] = []
    @State private var isLoadingTimeline = false
    @State private var isProcessing = false
    private let clipLength: Double = 10
    private var duration: Double {
        max(media.duration ?? 42, clipLength)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        BrandHeader(
                            eyebrow: "视频过长",
                            title: "选一段 10 秒片段",
                            subtitle: "拖动时间轴，把最清楚的画面放进选区。"
                        )

                        preview

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(timeText(start))
                                Spacer()
                                Text(timeText(min(start + clipLength, duration)))
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)

                            VideoTimelinePicker(
                                thumbnails: thumbnails,
                                start: $start,
                                duration: duration,
                                clipLength: clipLength,
                                isLoading: isLoadingTimeline
                            ) {
                                playSelectedClip()
                            }
                        }
                        .padding(18)
                        .cardSurface(cornerRadius: 24)

                        Button {
                            guard !isProcessing else { return }
                            isProcessing = true
                            onUseClip(start, start + clipLength)
                        } label: {
                            HStack(spacing: 8) {
                                if isProcessing {
                                    ProgressView()
                                        .tint(AppTheme.primaryButtonText)
                                }
                                Text(isProcessing ? "正在处理片段" : "使用这 10 秒识别")
                            }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle(isLoading: isProcessing))
                        .disabled(isProcessing)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("截取片段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                        .disabled(isProcessing)
                }
            }
            .task {
                setupPlayerIfNeeded()
                await loadThumbnails()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: AppTheme.ink.opacity(0.10), radius: 18, x: 0, y: 12)
        } else {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.30, green: 0.55, blue: 0.58),
                        Color(red: 0.09, green: 0.25, blue: 0.29),
                        AppTheme.sand
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text("示例视频 · 00:42")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(16)
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.10), radius: 18, x: 0, y: 12)
        }
    }

    private func setupPlayerIfNeeded() {
        guard player == nil, let url = media.url else { return }
        player = AVPlayer(url: url)
    }

    private func playSelectedClip() {
        setupPlayerIfNeeded()
        guard let player else { return }
        player.pause()
        player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            player.play()
        }
    }

    private func timeText(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    @MainActor
    private func loadThumbnails() async {
        guard thumbnails.isEmpty, let url = media.url else { return }
        isLoadingTimeline = true
        defer { isLoadingTimeline = false }
        thumbnails = (try? await makeThumbnails(for: url, count: 10)) ?? []
    }

    private func makeThumbnails(for url: URL, count: Int) async throws -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = max(CMTimeGetSeconds(duration), 1)
        return try await Array(0..<count).asyncMap { index in
            let ratio = count > 1 ? Double(index) / Double(count - 1) : 0
            let position = min(durationSeconds * ratio, max(durationSeconds - 0.1, 0))
            return try await thumbnail(for: asset, at: position)
        }
    }

    private func thumbnail(for asset: AVURLAsset, at seconds: Double) async throws -> UIImage {
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        let image = try await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)
            return try generator.copyCGImage(at: time, actualTime: nil)
        }.value
        return UIImage(cgImage: image)
    }
}

private struct VideoTimelinePicker: View {
    let thumbnails: [UIImage]
    @Binding var start: Double
    let duration: Double
    let clipLength: Double
    let isLoading: Bool
    let onEditingEnded: () -> Void
    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let contentWidth = max(width * CGFloat(duration / max(clipLength, 1)), width)

            ZStack(alignment: .leading) {
                timelineImages(contentWidth: contentWidth)
                    .frame(width: contentWidth)
                    .offset(x: -offset(contentWidth: contentWidth, viewportWidth: width))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.ink.opacity(0.90), lineWidth: 3)
                    .overlay(alignment: .leading) {
                        selectionHandle
                    }
                    .overlay(alignment: .trailing) {
                        selectionHandle
                    }

                HStack {
                    Text("固定 10 秒")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                    Spacer()
                }
                .padding(8)
            }
            .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = start
                        }
                        let maxStart = max(duration - clipLength, 0)
                        let available = max(contentWidth - width, 1)
                        let secondsPerPoint = maxStart / Double(available)
                        let nextStart = (dragStart ?? start) - Double(value.translation.width) * secondsPerPoint
                        start = min(max(nextStart, 0), maxStart)
                    }
                    .onEnded { _ in
                        dragStart = nil
                        onEditingEnded()
                    }
            )
        }
        .frame(height: 82)
    }

    private var selectionHandle: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(AppTheme.ink.opacity(0.85))
            .frame(width: 3, height: 46)
            .padding(.horizontal, 8)
    }

    private func timelineImages(contentWidth: CGFloat) -> some View {
        ZStack {
            if thumbnails.isEmpty {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.seaGlass.opacity(0.20))
                if isLoading {
                    ProgressView()
                        .tint(AppTheme.ink)
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: max(contentWidth / CGFloat(thumbnails.count), 1), height: 82)
                            .clipped()
                    }
                }
                .frame(width: contentWidth, height: 82, alignment: .leading)
                .background(alignment: .trailing) {
                    if let last = thumbnails.last {
                        Image(uiImage: last)
                            .resizable()
                            .scaledToFill()
                            .frame(width: max(contentWidth / CGFloat(thumbnails.count), 1), height: 82)
                            .clipped()
                    }
                }
                .overlay(Color.black.opacity(0.12))
            }
        }
    }

    private func offset(contentWidth: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let maxStart = max(duration - clipLength, 0)
        guard maxStart > 0 else { return 0 }
        let available = max(contentWidth - viewportWidth, 0)
        return available * CGFloat(min(max(start / maxStart, 0), 1))
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            let value = try await transform(element)
            values.append(value)
        }
        return values
    }
}
