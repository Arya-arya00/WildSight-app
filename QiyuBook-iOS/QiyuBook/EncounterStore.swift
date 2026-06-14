import Foundation
import SwiftUI

final class EncounterStore: ObservableObject {
    @Published private(set) var records: [EncounterRecord] = EncounterStore.loadRecords()
    @Published var highlightedRecordID: UUID?

    func record(id: UUID) -> EncounterRecord? {
        records.first { $0.id == id }
    }

    @discardableResult
    func save(_ record: EncounterRecord) -> EncounterRecord {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
            persist()
            return records[index]
        }
        records.insert(record, at: 0)
        persist()
        return record
    }

    @discardableResult
    func createMockRecord(mediaKind: MediaKind, mediaURL: URL? = nil, referenceImageURL: URL? = nil, trimStart: Double? = nil, trimEnd: Double? = nil) -> EncounterRecord {
        let record = EncounterRecord(
            name: "玳瑁海龟",
            latin: "Hawksbill Sea Turtle · 海龟科",
            confidence: "较明确",
            summary: "尖尖的鹰钩嘴，加上像瓦片一样叠起来的背甲，基本就是海龟界的复古穿搭选手。",
            facts: [
                EncounterFact(title: "怎么认", text: "看侧脸的尖嘴、背甲边缘和鳞片叠法。"),
                EncounterFact(title: "在干嘛", text: "常在珊瑚附近找海绵和小型无脊椎动物。"),
                EncounterFact(title: "小心点", text: "保持距离，不挡它的路；它慢，不代表想被贴脸拍。")
            ],
            artworkBase64: nil,
            mediaKind: mediaKind,
            mediaURL: mediaURL,
            referenceImageURL: referenceImageURL,
            observedAt: Self.nowText(),
            location: "未填写地点",
            latitude: nil,
            longitude: nil,
            tags: ["海龟", "濒危"],
            trimStart: trimStart,
            trimEnd: trimEnd
        )
        records.insert(record, at: 0)
        persist()
        return record
    }

    @discardableResult
    func createRecord(
        from response: IdentifyResponse,
        mediaKind: MediaKind,
        mediaURL: URL? = nil,
        referenceImageURL: URL? = nil,
        observedAt: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        trimStart: Double? = nil,
        trimEnd: Double? = nil
    ) -> EncounterRecord {
        let record = draftRecord(
            from: response,
            mediaKind: mediaKind,
            mediaURL: mediaURL,
            referenceImageURL: referenceImageURL,
            observedAt: observedAt,
            location: location,
            latitude: latitude,
            longitude: longitude,
            trimStart: trimStart,
            trimEnd: trimEnd
        )
        records.insert(record, at: 0)
        persist()
        return record
    }

    func draftRecord(
        from response: IdentifyResponse,
        mediaKind: MediaKind,
        mediaURL: URL? = nil,
        referenceImageURL: URL? = nil,
        observedAt: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        trimStart: Double? = nil,
        trimEnd: Double? = nil
    ) -> EncounterRecord {
        EncounterRecord(
            name: response.name,
            latin: response.latin ?? "分类待确认",
            confidence: response.confidence ?? "不确定",
            summary: response.summary,
            facts: response.facts.map { EncounterFact(title: $0.title, text: $0.text) },
            artworkBase64: response.artworkBase64,
            mediaKind: mediaKind,
            mediaURL: mediaURL,
            referenceImageURL: referenceImageURL,
            observedAt: observedAt ?? Self.nowText(),
            location: location ?? "未填写地点",
            latitude: latitude,
            longitude: longitude,
            tags: response.tags ?? [],
            trimStart: trimStart,
            trimEnd: trimEnd
        )
    }

    func update(_ record: EncounterRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        persist()
    }

    func updateArtwork(id: UUID, artworkBase64: String) -> EncounterRecord? {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return nil }
        records[index].artworkBase64 = artworkBase64
        persist()
        return records[index]
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        if highlightedRecordID == id {
            highlightedRecordID = nil
        }
        persist()
    }

    func highlightSavedRecord(id: UUID) {
        highlightedRecordID = id
    }

    static func nowText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: Date())
    }

    private static let samples: [EncounterRecord] = [
        EncounterRecord(
            name: "玳瑁海龟",
            latin: "Hawksbill Sea Turtle · 海龟科",
            confidence: "较明确",
            summary: "尖尖的鹰钩嘴，加上像瓦片一样叠起来的背甲，基本就是海龟界的复古穿搭选手。",
            facts: [
                EncounterFact(title: "怎么认", text: "看侧脸的尖嘴、背甲边缘和鳞片叠法。"),
                EncounterFact(title: "在干嘛", text: "常在珊瑚附近找海绵和小型无脊椎动物。"),
                EncounterFact(title: "小心点", text: "保持距离，不挡它的路；它慢，不代表想被贴脸拍。")
            ],
            artworkBase64: nil,
            mediaKind: .video,
            mediaURL: nil,
            referenceImageURL: nil,
            observedAt: "2026.02.25 15:42",
            location: "菲律宾 阿尼洛",
            latitude: nil,
            longitude: nil,
            tags: ["海龟", "濒危"],
            trimStart: 6,
            trimEnd: 16
        ),
        EncounterRecord(
            name: "鹰鳐",
            latin: "Eagle Ray · 鳐科",
            confidence: "较明确",
            summary: "背着星星点点的斑纹巡航，像海里飞过的一张小毯子。",
            facts: [
                EncounterFact(title: "怎么认", text: "尖头、宽大的胸鳍和背部斑点是重点。"),
                EncounterFact(title: "在干嘛", text: "常在沙地附近找贝类或小型甲壳动物。"),
                EncounterFact(title: "小心点", text: "远远看就好，不要追着它游。")
            ],
            artworkBase64: nil,
            mediaKind: .image,
            mediaURL: nil,
            referenceImageURL: nil,
            observedAt: "2025.10.03 10:20",
            location: "科莫多",
            latitude: nil,
            longitude: nil,
            tags: ["鳐鱼", "星空背"]
        )
    ]

    private static var storageURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("encounter-records.json")
    }

    private static func loadRecords() -> [EncounterRecord] {
        guard
            let data = try? Data(contentsOf: storageURL),
            let records = try? JSONDecoder().decode([EncounterRecord].self, from: data)
        else {
            return samples
        }
        return records
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: Self.storageURL, options: .atomic)
    }
}
