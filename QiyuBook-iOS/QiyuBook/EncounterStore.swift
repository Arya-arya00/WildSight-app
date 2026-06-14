import Foundation
import SwiftUI

enum SampleContentKind {
    case photo
    case shortVideo
    case longVideo
}

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

    func sampleDraft(kind: SampleContentKind) -> EncounterRecord {
        let record = Self.sampleRecord(kind: kind)
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

    private static func sampleRecord(kind: SampleContentKind) -> EncounterRecord {
        switch kind {
        case .photo:
            return EncounterRecord(
                name: "蝠鲼",
                latin: "Mobula birostris · 蝠鲼科",
                confidence: "较明确",
                summary: "它像一张巨大的黑色披风从水里滑过，宽阔胸鳍一扇，整个海面都像慢了下来。",
                facts: [
                    EncounterFact(title: "它是谁：温和的滤食者", text: "蝠鲼属于软骨鱼类，身体扁宽，两侧胸鳍像翅膀，头前有一对头鳍，会帮助把浮游生物送入口中。"),
                    EncounterFact(title: "怎么生活：边游边过滤", text: "它们主要吃浮游动物和小型鱼虾，常在水中张口巡游，用鳃耙把食物从海水中过滤出来。"),
                    EncounterFact(title: "冷知识：会去清洁站排队", text: "很多蝠鲼会固定来到礁区清洁站，让小鱼帮它们清理寄生虫，像海里的温柔洗车房。")
                ],
                artworkBase64: Self.sampleArtworkBase64(fileName: "sample_manta_artwork"),
                mediaKind: .image,
                mediaURL: Self.sampleMediaURL(name: "manta", extension: "jpg"),
                referenceImageURL: Self.sampleMediaURL(name: "manta", extension: "jpg"),
                observedAt: Self.nowText(),
                location: "示例地点",
                latitude: nil,
                longitude: nil,
                tags: ["海洋生物", "滤食者"]
            )
        case .shortVideo:
            return EncounterRecord(
                name: "栉水母",
                latin: "Ctenophora · 栉水母动物",
                confidence: "较明确",
                summary: "看起来像一团透明果冻，其实身上藏着会折射彩光的小梳子。",
                facts: [
                    EncounterFact(title: "它是谁：透明的栉水母", text: "栉水母不是普通水母。它们没有刺细胞，身体通常透明，靠一排排像梳齿的纤毛板在水中移动。"),
                    EncounterFact(title: "怎么生活：慢慢漂也会捕食", text: "它们多在水体中漂游，捕食小型浮游动物。有些种类会用黏性的触手捕捉猎物。"),
                    EncounterFact(title: "冷知识：彩虹不是它在发光", text: "你看到的彩色闪烁，多数是纤毛板运动时对光的折射，不一定是生物发光。")
                ],
                artworkBase64: Self.sampleArtworkBase64(fileName: "sample_jellyfish_artwork"),
                mediaKind: .video,
                mediaURL: Self.sampleMediaURL(name: "jellyfish_4s", extension: "mp4"),
                referenceImageURL: nil,
                observedAt: Self.nowText(),
                location: "示例地点",
                latitude: nil,
                longitude: nil,
                tags: ["透明生物", "浮游"]
            )
        case .longVideo:
            return EncounterRecord(
                name: "鹰鳐",
                latin: "Aetobatus sp. · 鹰鲼科",
                confidence: "较明确",
                summary: "它在海底上方巡航时，真的很像一架安静的小飞行器。",
                facts: [
                    EncounterFact(title: "它是谁：会飞的鳐", text: "鹰鳐身体扁宽，胸鳍像翅膀，尾巴细长。很多个体背部带有斑点，游动时像在水里滑翔。"),
                    EncounterFact(title: "怎么生活：爱翻沙找饭", text: "它们常在沙地或礁区附近寻找贝类、螺类和甲壳动物，会用口部和牙板处理硬壳猎物。"),
                    EncounterFact(title: "冷知识：鼻头像鸭嘴", text: "鹰鳐头部前端突出，轮廓有点像鸭嘴，这也是潜水时辨认它的重要线索之一。")
                ],
                artworkBase64: Self.sampleArtworkBase64(fileName: "sample_eagle_ray_artwork"),
                mediaKind: .video,
                mediaURL: Self.sampleMediaURL(name: "eagle_ray_25s", extension: "mp4"),
                referenceImageURL: nil,
                observedAt: Self.nowText(),
                location: "示例地点",
                latitude: nil,
                longitude: nil,
                tags: ["鳐鱼", "底栖巡游"],
                trimStart: 8,
                trimEnd: 18
            )
        }
    }

    private static func sampleMediaURL(name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "SampleMedia")
    }

    private static func sampleArtworkBase64(fileName: String) -> String? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "jpg", subdirectory: "SampleMedia"),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return data.base64EncodedString()
    }

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
