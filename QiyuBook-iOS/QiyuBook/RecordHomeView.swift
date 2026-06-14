import AVFoundation
import CoreLocation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PickedMediaMetadata {
    var observedAt: String?
    var location: String?
    var latitude: Double?
    var longitude: Double?

    static let empty = PickedMediaMetadata()
}

struct PersistedMedia {
    var url: URL?
    var referenceImageURL: URL?
    var metadata: PickedMediaMetadata
}

struct PickedMedia: Identifiable {
    let id = UUID()
    var kind: MediaKind
    var url: URL?
    var isLongVideo: Bool
    var duration: Double?
    var metadata: PickedMediaMetadata
    var referenceImageURL: URL?
}

private struct PreparedUploadMedia {
    var identifyURL: URL?
    var identifyKind: MediaKind
    var referenceImageURL: URL?
}

struct RecordHomeView: View {
    @EnvironmentObject private var store: EncounterStore
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoadingMedia = false
    @State private var activeResult: ActiveRecord?
    @State private var activeDraft: EncounterRecord?
    @State private var pendingTrim: PickedMedia?
    @State private var errorMessage: String?
    @State private var showPhotoPicker = false
    @State private var showSamplePicker = false

    var body: some View {
        ZStack {
            AppTheme.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 34) {
                    BrandHeader(
                        eyebrow: "",
                        title: "让好奇识得万物"
                    )
                    .padding(.top, 18)

                    uploadPanel
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("识野")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoadingMedia {
                ProgressView("正在识别")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .task(id: selectedItem) {
            guard let selectedItem else { return }
            await handlePickedItem(selectedItem)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .any(of: [.images, .videos]), photoLibrary: .shared())
        .navigationDestination(item: $activeResult) { active in
            if let record = store.record(id: active.id) {
                ResultView(record: record)
            }
        }
        .navigationDestination(item: $activeDraft) { draft in
            ResultView(record: draft, isSaved: false)
        }
        .sheet(item: $pendingTrim) { media in
            TrimSelectionView(media: media) { start, end in
                Task {
                    await identifyAndOpenResult(
                        mediaKind: media.kind,
                        mediaURL: media.url,
                        referenceImageURL: media.referenceImageURL,
                        metadata: media.metadata,
                        trimStart: start,
                        trimEnd: end
                    )
                }
            }
            .presentationDetents([.large])
        }
        .alert("识别失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("选择示例内容", isPresented: $showSamplePicker) {
            Button("示例照片") {
                createSample(kind: .image)
            }
            Button("示例短视频") {
                createSample(kind: .video)
            }
            Button("示例长视频，进入裁剪") {
                pendingTrim = PickedMedia(kind: .video, url: nil, isLongVideo: true, duration: 42, metadata: .empty, referenceImageURL: nil)
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var uploadPanel: some View {
        VStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: AppTheme.shadow.opacity(0.10), radius: 14, x: 0, y: 9)

            Text("上传动物的图片或视频，我会带你认识它。")
                .font(.callout)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 10)

            VStack(spacing: 10) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(isLoadingMedia ? "识别中..." : "上传图片或视频", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryActionButtonStyle(isLoading: isLoadingMedia))
                .disabled(isLoadingMedia)

                Button {
                    showSamplePicker = true
                } label: {
                    Text("使用示例内容")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
            .padding(18)
            .cardSurface(cornerRadius: 24)
    }

    private func createSample(kind: MediaKind) {
        let record = store.createMockRecord(mediaKind: kind)
        activeResult = ActiveRecord(id: record.id)
    }

    @MainActor
    private func handlePickedItem(_ item: PhotosPickerItem) async {
        isLoadingMedia = true
        defer {
            isLoadingMedia = false
            selectedItem = nil
        }

        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }
        let kind: MediaKind = isVideo ? .video : .image

        do {
            let persisted = try await persistPickedItem(item, mediaKind: kind)
            if kind == .video, let url = persisted.url {
                let duration = try await videoDuration(for: url)
                if duration > 10 {
                    pendingTrim = PickedMedia(kind: .video, url: url, isLongVideo: true, duration: duration, metadata: persisted.metadata, referenceImageURL: nil)
                } else {
                    await identifyAndOpenResult(mediaKind: .video, mediaURL: url, referenceImageURL: persisted.referenceImageURL, metadata: persisted.metadata)
                }
            } else {
                await identifyAndOpenResult(mediaKind: .image, mediaURL: persisted.url, referenceImageURL: persisted.referenceImageURL, metadata: persisted.metadata)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistPickedItem(_ item: PhotosPickerItem, mediaKind: MediaKind) async throws -> PersistedMedia {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            return PersistedMedia(url: nil, referenceImageURL: nil, metadata: .empty)
        }

        let ext = mediaKind == .video ? "mov" : "jpg"
        let url = try mediaStorageURL(fileExtension: ext)
        try data.write(to: url, options: .atomic)
        let metadata = mediaKind == .image ? await imageMetadata(from: data) : .empty
        if mediaKind == .video {
            let compressedURL = (try? await compressedVideoURL(from: url)) ?? url
            return PersistedMedia(url: compressedURL, referenceImageURL: nil, metadata: metadata)
        }
        let referenceImageURL = mediaKind == .image ? url : nil
        return PersistedMedia(url: url, referenceImageURL: referenceImageURL, metadata: metadata)
    }

    private func compressedVideoURL(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let outputURL = try mediaStorageURL(fileExtension: "mp4")
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540)
            ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)
        else {
            throw AIIdentifyError.badServerResponse("无法压缩视频。")
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: exportSession.error ?? AIIdentifyError.badServerResponse("视频压缩失败。"))
                default:
                    continuation.resume(throwing: AIIdentifyError.badServerResponse("视频压缩未完成。"))
                }
            }
        }
        return outputURL
    }

    private func videoDuration(for url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    @MainActor
    private func identifyAndOpenResult(
        mediaKind: MediaKind,
        mediaURL: URL?,
        referenceImageURL: URL? = nil,
        metadata: PickedMediaMetadata = .empty,
        trimStart: Double? = nil,
        trimEnd: Double? = nil
    ) async {
        isLoadingMedia = true
        defer {
            isLoadingMedia = false
            pendingTrim = nil
        }

        do {
            let preparedMedia = try await preparedUploadMedia(
                mediaKind: mediaKind,
                mediaURL: mediaURL,
                referenceImageURL: referenceImageURL,
                trimStart: trimStart
            )

            let response = try await AIIdentifyClient().identify(
                mediaURL: preparedMedia.identifyURL,
                mediaKind: preparedMedia.identifyKind,
                trimStart: trimStart,
                trimEnd: trimEnd
            )
            if let response {
                try validate(response: response, mediaKind: mediaKind)
                activeDraft = store.draftRecord(
                    from: response,
                    mediaKind: mediaKind,
                    mediaURL: mediaURL,
                    referenceImageURL: preparedMedia.referenceImageURL,
                    observedAt: metadata.observedAt,
                    location: metadata.location,
                    latitude: metadata.latitude,
                    longitude: metadata.longitude,
                    trimStart: trimStart,
                    trimEnd: trimEnd
                )
            } else {
                let record = store.createMockRecord(mediaKind: mediaKind, mediaURL: mediaURL, referenceImageURL: preparedMedia.referenceImageURL, trimStart: trimStart, trimEnd: trimEnd)
                activeResult = ActiveRecord(id: record.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validate(response: IdentifyResponse, mediaKind: MediaKind) throws {
        let status = response.status?.lowercased() ?? ""
        let confidence = response.confidence ?? ""
        guard mediaKind == .video else { return }
        if status == "unknown" || confidence.contains("看不清") || confidence.contains("不确定") {
            throw AIIdentifyError.badServerResponse("这段视频里的主体不够清楚，暂时不保存记录。请换一段更清楚的 10 秒片段再试。")
        }
    }

    private func preparedUploadMedia(
        mediaKind: MediaKind,
        mediaURL: URL?,
        referenceImageURL: URL?,
        trimStart: Double?
    ) async throws -> PreparedUploadMedia {
        guard mediaKind == .video else {
            return PreparedUploadMedia(
                identifyURL: mediaURL,
                identifyKind: mediaKind,
                referenceImageURL: referenceImageURL ?? mediaURL
            )
        }
        guard let mediaURL else {
            throw AIIdentifyError.missingMedia
        }
        let bundle = try await videoReferenceBundle(for: mediaURL, trimStart: trimStart)
        return PreparedUploadMedia(
            identifyURL: bundle.contactSheetURL,
            identifyKind: .image,
            referenceImageURL: referenceImageURL ?? bundle.referenceImageURL
        )
    }

    private func mediaStorageURL(fileExtension ext: String) throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    private func keyFrameImageURL(for videoURL: URL, at seconds: Double) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let image = try await videoFrameImage(for: asset, at: seconds)
        return try imageURL(from: image, quality: 0.82)
    }

    private func videoReferenceBundle(for videoURL: URL, trimStart: Double?) async throws -> (referenceImageURL: URL, contactSheetURL: URL) {
        let asset = AVURLAsset(url: videoURL)
        let start = trimStart ?? 0
        let offsets = [1.0, 5.0, 9.0]
        let images = try await offsets.asyncMap { offset in
            try await videoFrameImage(for: asset, at: start + offset)
        }
        let referenceImage = images[safe: images.count / 2] ?? images[0]
        return (
            referenceImageURL: try imageURL(from: referenceImage, quality: 0.82),
            contactSheetURL: try contactSheetURL(from: images)
        )
    }

    private func videoFrameImage(for asset: AVURLAsset, at seconds: Double) async throws -> UIImage {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let safeSeconds: Double
        if durationSeconds.isFinite, durationSeconds > 0 {
            safeSeconds = min(max(0, seconds), max(0, durationSeconds - 0.1))
        } else {
            safeSeconds = max(0, seconds)
        }
        let time = CMTime(seconds: safeSeconds, preferredTimescale: 600)
        let image = try await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1400, height: 1400)
            return try generator.copyCGImage(at: time, actualTime: nil)
        }.value
        return UIImage(cgImage: image)
    }

    private func imageURL(from image: UIImage, quality: CGFloat) throws -> URL {
        let url = try mediaStorageURL(fileExtension: "jpg")
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw AIIdentifyError.badServerResponse("无法从视频中截取清晰画面。")
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private func contactSheetURL(from images: [UIImage]) throws -> URL {
        guard !images.isEmpty else {
            throw AIIdentifyError.badServerResponse("无法从视频中截取清晰画面。")
        }
        let targetSize = CGSize(width: 1200, height: 760)
        let cellWidth = targetSize.width / CGFloat(images.count)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let image = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            for (index, frame) in images.enumerated() {
                let rect = CGRect(x: CGFloat(index) * cellWidth, y: 0, width: cellWidth, height: targetSize.height)
                frame.drawAspectFill(in: rect.insetBy(dx: 6, dy: 6))
            }
        }
        return try imageURL(from: image, quality: 0.78)
    }

    private func imageMetadata(from data: Data) async -> PickedMediaMetadata {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return .empty
        }

        let observedAt = metadataDate(from: properties)
        let coordinate = gpsCoordinate(from: properties)
        let locationName: String?
        if let coordinate {
            locationName = await reverseGeocode(coordinate)
        } else {
            locationName = nil
        }

        #if DEBUG
        print("Picked image metadata: date=\(observedAt ?? "none"), gps=\(coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "none"), place=\(locationName ?? "none")")
        #endif

        return PickedMediaMetadata(
            observedAt: observedAt,
            location: locationName,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        )
    }

    private func metadataDate(from properties: [String: Any]) -> String? {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let rawDate = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime as String] as? String
        guard let rawDate else { return nil }

        let input = DateFormatter()
        input.dateFormat = "yyyy:MM:dd HH:mm:ss"
        guard let date = input.date(from: rawDate) else { return nil }

        let output = DateFormatter()
        output.dateFormat = "yyyy.MM.dd HH:mm"
        return output.string(from: date)
    }

    private func gpsCoordinate(from properties: [String: Any]) -> CLLocationCoordinate2D? {
        guard let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }
        guard
            var latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
            var longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double
        else {
            return nil
        }

        let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String
        let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
        if latitudeRef == "S" { latitude = -latitude }
        if longitudeRef == "W" { longitude = -longitude }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            return placemarks.first?.compactDisplayName
        } catch {
            return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
        }
    }
}

#Preview {
    NavigationStack {
        RecordHomeView()
            .environmentObject(EncounterStore())
    }
}

private extension CLPlacemark {
    var compactDisplayName: String? {
        let parts = [name, locality, administrativeArea, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        var uniqueParts: [String] = []
        for part in parts where !uniqueParts.contains(part) {
            uniqueParts.append(part)
        }
        return uniqueParts.isEmpty ? nil : uniqueParts.joined(separator: " ")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

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

private extension UIImage {
    func drawAspectFill(in rect: CGRect) {
        let widthRatio = rect.width / size.width
        let heightRatio = rect.height / size.height
        let scale = max(widthRatio, heightRatio)
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: rect.midX - scaledSize.width / 2,
            y: rect.midY - scaledSize.height / 2
        )
        draw(in: CGRect(origin: origin, size: scaledSize))
    }
}
