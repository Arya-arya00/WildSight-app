import Foundation
import UIKit

enum AIIdentifyError: LocalizedError {
    case invalidEndpoint
    case missingMedia
    case badServerResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "识别服务地址不正确。"
        case .missingMedia:
            return "没有找到要上传的图片或视频。"
        case .badServerResponse(let message):
            return message
        }
    }
}

struct AIIdentifyClient {
    func identify(mediaURL: URL?, mediaKind: MediaKind, trimStart: Double? = nil, trimEnd: Double? = nil) async throws -> IdentifyResponse? {
        let endpoint = APIConfig.identifyEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { return nil }
        guard let url = URL(string: endpoint), ["http", "https"].contains(url.scheme) else {
            throw AIIdentifyError.invalidEndpoint
        }
        guard let mediaURL else {
            throw AIIdentifyError.missingMedia
        }

        var request = URLRequest(url: url)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeMultipartBody(
            boundary: boundary,
            mediaURL: mediaURL,
            mediaKind: mediaKind,
            trimStart: trimStart,
            trimEnd: trimEnd
        )

        let (data, response) = try await requestData(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AIIdentifyError.badServerResponse(errorMessage(from: data))
        }

        do {
            return try JSONDecoder().decode(IdentifyResponse.self, from: data)
        } catch {
            throw AIIdentifyError.badServerResponse("识别服务返回了无法读取的结果。")
        }
    }

    func generateArtwork(mediaURL: URL?, record: EncounterRecord) async throws -> String? {
        let endpoint = APIConfig.artworkEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { return nil }
        guard let url = URL(string: endpoint), ["http", "https"].contains(url.scheme) else {
            throw AIIdentifyError.invalidEndpoint
        }
        guard let mediaURL else {
            throw AIIdentifyError.missingMedia
        }

        var request = URLRequest(url: url)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeArtworkMultipartBody(boundary: boundary, mediaURL: mediaURL, record: record)

        let (data, response) = try await requestData(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AIIdentifyError.badServerResponse(errorMessage(from: data))
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let artworkBase64 = object["artworkBase64"] as? String,
            !artworkBase64.isEmpty
        else {
            throw AIIdentifyError.badServerResponse("手绘图生成结果无法读取。")
        }
        return artworkBase64
    }

    private func requestData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw AIIdentifyError.badServerResponse(networkErrorMessage(error))
        } catch {
            throw error
        }
    }

    private func networkErrorMessage(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut:
            return "连不上本机识别服务。请确认 iPhone 和 Mac 在同一个 Wi-Fi，并在 iPhone 设置里允许“识野”访问本地网络。"
        case .appTransportSecurityRequiresSecureConnection:
            return "iPhone 拦截了本机 HTTP 请求。请检查 App 的本地调试网络配置。"
        default:
            return "识别服务连接失败：\(error.localizedDescription)"
        }
    }

    private func errorMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["error"] as? String
        else {
            return "识别服务请求失败。"
        }
        return message
    }

    private func makeMultipartBody(boundary: String, mediaURL: URL, mediaKind: MediaKind, trimStart: Double?, trimEnd: Double?) throws -> Data {
        var data = Data()
        let mediaData = try uploadData(for: mediaURL, mediaKind: mediaKind)
        let fileName = mediaURL.lastPathComponent
        let mimeType = mediaKind == .video ? "video/quicktime" : "image/jpeg"

        data.appendField(name: "mediaKind", value: mediaKind.rawValue, boundary: boundary)
        data.appendField(name: "observedAt", value: EncounterStore.nowText(), boundary: boundary)
        if let trimStart {
            data.appendField(name: "trimStart", value: String(trimStart), boundary: boundary)
        }
        if let trimEnd {
            data.appendField(name: "trimEnd", value: String(trimEnd), boundary: boundary)
        }

        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\r\n")
        data.append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(mediaData)
        data.append("\r\n")
        data.append("--\(boundary)--\r\n")

        return data
    }

    private func makeArtworkMultipartBody(boundary: String, mediaURL: URL, record: EncounterRecord) throws -> Data {
        var data = Data()
        let mediaData = try compressedImageData(for: mediaURL, maxSide: 900, quality: 0.68)
        let fileName = mediaURL.lastPathComponent

        data.appendField(name: "name", value: record.name, boundary: boundary)
        data.appendField(name: "latin", value: record.latin, boundary: boundary)
        data.appendField(name: "summary", value: record.summary, boundary: boundary)
        data.appendField(name: "tags", value: record.tags.joined(separator: ","), boundary: boundary)

        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\r\n")
        data.append("Content-Type: image/jpeg\r\n\r\n")
        data.append(mediaData)
        data.append("\r\n")
        data.append("--\(boundary)--\r\n")

        return data
    }

    private func uploadData(for mediaURL: URL, mediaKind: MediaKind) throws -> Data {
        switch mediaKind {
        case .image:
            return try compressedImageData(for: mediaURL, maxSide: 1400, quality: 0.76)
        case .video:
            return try Data(contentsOf: mediaURL)
        }
    }

    private func compressedImageData(for url: URL, maxSide: CGFloat, quality: CGFloat) throws -> Data {
        let originalData = try Data(contentsOf: url)
        guard let image = UIImage(data: originalData) else {
            return originalData
        }

        let longestSide = max(image.size.width, image.size.height)
        let targetSize: CGSize
        if longestSide > maxSide {
            let ratio = maxSide / longestSide
            targetSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        } else {
            targetSize = image.size
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: quality) ?? originalData
    }
}

private extension Data {
    mutating func appendField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
