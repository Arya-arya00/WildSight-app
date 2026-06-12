import SwiftUI
import AVKit
import UIKit

struct BrandHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.faintText)
            }
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GeneratedCardArt: View {
    var artworkBase64: String?
    var sourceMediaURL: URL?
    var isGeneratingArtwork = false
    var compact = false
    var mediaLabel: String?
    var loadingText = "正在绘制记录卡"
    var onPreview: (() -> Void)?

    var body: some View {
        ZStack {
            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(compact ? 8 : 12)
                    .background(AppTheme.card)
            } else if let sourceImage {
                ZStack {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .blur(radius: compact ? 8 : 14)
                        .saturation(0.72)
                        .opacity(0.78)

                    Rectangle()
                        .fill(.ultraThinMaterial)

                    if isGeneratingArtwork {
                        VStack(spacing: compact ? 6 : 10) {
                            ProgressView()
                                .controlSize(compact ? .small : .regular)
                                .tint(AppTheme.ink)
                            Text(loadingText)
                                .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                        }
                        .padding(.horizontal, compact ? 10 : 16)
                        .padding(.vertical, compact ? 8 : 12)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                    }
                }
            } else {
                MockCardArt(compact: compact)
            }

            if let mediaLabel, let onPreview {
                Button(action: onPreview) {
                    Label("原\(mediaLabel)", systemImage: mediaLabel == "视频" ? "play.rectangle" : "photo")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.ink.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(compact ? 10 : 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 18 : 30, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.07), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var generatedImage: UIImage? {
        guard
            let artworkBase64,
            let data = Data(base64Encoded: artworkBase64)
        else {
            return nil
        }
        return UIImage(data: data)
    }

    private var sourceImage: UIImage? {
        guard let sourceMediaURL else { return nil }
        return UIImage(contentsOfFile: sourceMediaURL.path)
    }
}

struct EncounterArtworkStage: View {
    var record: EncounterRecord
    var isGeneratingArtwork: Bool
    var onEditMeta: () -> Void
    var onPreview: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            GeneratedCardArt(
                artworkBase64: record.artworkBase64,
                sourceMediaURL: record.referenceImageURL ?? record.mediaURL,
                isGeneratingArtwork: isGeneratingArtwork,
                mediaLabel: record.mediaKind.label,
                onPreview: onPreview
            )

            MetaPill(text: "\(record.observedAt) · \(record.location)", action: onEditMeta)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

struct MockCardArt: View {
    var compact = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 22 : 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.93, blue: 0.91),
                            Color(red: 1.00, green: 0.96, blue: 0.86)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .topLeading) {
                    Text("✦")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.85, green: 0.66, blue: 0.36))
                        .padding(compact ? 12 : 20)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text("✿")
                        .font(.title3)
                        .foregroundStyle(AppTheme.seaGlass)
                        .padding(compact ? 14 : 22)
                }

            TurtleSticker()
                .scaleEffect(compact ? 0.56 : 1.18)
                .offset(x: compact ? -4 : 4, y: compact ? 8 : 16)
        }
    }
}

struct TurtleSticker: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.50, green: 0.61, blue: 0.41),
                            Color(red: 0.78, green: 0.75, blue: 0.63)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 118, height: 90)
                .overlay(Ellipse().stroke(Color(red: 0.33, green: 0.29, blue: 0.24).opacity(0.62), lineWidth: 4))
                .overlay(
                    Circle()
                        .fill(.white.opacity(0.26))
                        .frame(width: 30, height: 30)
                        .offset(x: -20, y: -12)
                )

            Ellipse()
                .fill(Color(red: 0.79, green: 0.75, blue: 0.63))
                .frame(width: 38, height: 30)
                .overlay(Ellipse().stroke(Color(red: 0.33, green: 0.29, blue: 0.24).opacity(0.62), lineWidth: 4))
                .offset(x: 66, y: 0)

            HStack(spacing: 14) {
                Circle().fill(AppTheme.ink).frame(width: 6, height: 6)
                Circle().fill(AppTheme.ink).frame(width: 6, height: 6)
            }
            .offset(x: 70, y: -2)

            ArcSmile()
                .stroke(AppTheme.ink.opacity(0.65), lineWidth: 2)
                .frame(width: 18, height: 9)
                .offset(x: 76, y: 8)

            Circle()
                .fill(Color(red: 0.45, green: 0.55, blue: 0.39))
                .frame(width: 24, height: 22)
                .offset(x: -34, y: 48)

            Circle()
                .fill(Color(red: 0.45, green: 0.55, blue: 0.39))
                .frame(width: 24, height: 22)
                .offset(x: 28, y: 48)
        }
        .shadow(color: Color(red: 0.44, green: 0.35, blue: 0.26).opacity(0.10), radius: 0, x: 0, y: 8)
        .frame(width: 180, height: 142)
    }
}

struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(25),
            endAngle: .degrees(155),
            clockwise: false
        )
        return path
    }
}

struct MetaPill: View {
    let text: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
            Spacer()
            Button(action: action) {
                Image(systemName: "pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.ink.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
    }
}

struct MediaPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: EncounterRecord

    var body: some View {
        NavigationStack {
            Group {
                if let mediaURL = record.mediaURL, record.mediaKind == .video {
                    VideoPlayer(player: AVPlayer(url: mediaURL))
                } else if let mediaURL = record.mediaURL, let image = UIImage(contentsOfFile: mediaURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    ContentUnavailableView("暂无原\(record.mediaKind.label)", systemImage: "photo.on.rectangle.angled", description: Text("示例记录没有绑定本地媒体。"))
                }
            }
            .navigationTitle("原\(record.mediaKind.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
