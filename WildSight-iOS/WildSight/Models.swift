import Foundation

enum MediaKind: String, Codable, CaseIterable {
    case image
    case video

    var label: String {
        switch self {
        case .image: return "照片"
        case .video: return "视频"
        }
    }
}

struct EncounterFact: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var text: String
}

struct EncounterRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var latin: String
    var confidence: String
    var summary: String
    var facts: [EncounterFact]
    var artworkBase64: String?
    var mediaKind: MediaKind
    var mediaURL: URL?
    var referenceImageURL: URL?
    var observedAt: String
    var location: String
    var latitude: Double?
    var longitude: Double?
    var tags: [String]
    var trimStart: Double?
    var trimEnd: Double?
    var createdAt = Date()
}

struct ActiveRecord: Identifiable, Hashable {
    let id: UUID
}

struct IdentifyFactResponse: Decodable {
    var title: String
    var text: String
}

struct IdentifyResponse: Decodable {
    var status: String?
    var confidence: String?
    var name: String
    var latin: String?
    var summary: String
    var facts: [IdentifyFactResponse]
    var tags: [String]?
    var artworkBase64: String?
}
