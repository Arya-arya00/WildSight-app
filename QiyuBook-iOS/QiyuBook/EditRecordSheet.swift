import CoreLocation
import SwiftUI

enum EditSheet: Identifiable, Hashable {
    case meta

    var id: String {
        "meta"
    }
}

struct EncounterContentCard: View {
    let record: EncounterRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.name)
                        .multilineTextAlignment(.leading)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(record.latin)
                        .multilineTextAlignment(.leading)
                        .font(.subheadline.italic())
                        .foregroundStyle(AppTheme.faintText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(accuracyLabel(for: record.confidence))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.kelp)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.kelp.opacity(0.14), in: Capsule())
                    .fixedSize()
            }

            Text(record.summary)
                .multilineTextAlignment(.leading)
                .font(.callout)
                .foregroundStyle(AppTheme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(record.facts) { fact in
                VStack(alignment: .leading, spacing: 7) {
                    Text(fact.title)
                        .multilineTextAlignment(.leading)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(fact.text)
                        .multilineTextAlignment(.leading)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Divider()
                        .background(AppTheme.line)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 28)
    }

    private func accuracyLabel(for confidence: String) -> String {
        if confidence.contains("无法识别") || confidence.contains("无法") || confidence.contains("看不出") || confidence.contains("没有主体") || confidence.contains("没有生物") {
            return "不确定"
        }
        if confidence.contains("模糊") || confidence.contains("不清") || confidence.contains("看不清") || confidence.contains("可能") || confidence.contains("猜测") || confidence.contains("低") {
            return "可能是"
        }
        if confidence.contains("准确") || confidence.contains("明确") || confidence.contains("确定") || confidence.contains("高") {
            return "一定是"
        }
        return "可能是"
    }
}

struct EditRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftTime: String = ""
    @State private var draftLocation: String = ""
    @State private var draftLatitude: Double?
    @State private var draftLongitude: Double?
    @State private var showLocationPicker = false

    let record: EncounterRecord
    let sheet: EditSheet
    let onSave: (EncounterRecord) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("时间和地点") {
                    TextField("时间", text: $draftTime)

                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "map")
                                .foregroundStyle(AppTheme.kelp)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draftLocation.isEmpty ? "选择地点 / POI" : draftLocation)
                                    .foregroundStyle(AppTheme.ink)
                                Text(locationHint)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.faintText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.faintText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .onAppear {
                seedDrafts()
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet(initialCoordinate: initialCoordinate) { selection in
                    draftLocation = selection.name
                    draftLatitude = selection.coordinate.latitude
                    draftLongitude = selection.coordinate.longitude
                }
            }
        }
    }

    private var title: String {
        "修改时间地点"
    }

    private var locationHint: String {
        if let draftLatitude, let draftLongitude {
            return String(format: "%.4f, %.4f", draftLatitude, draftLongitude)
        }
        return "从地图上选择一个位置"
    }

    private var initialCoordinate: CLLocationCoordinate2D? {
        guard let draftLatitude, let draftLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: draftLatitude, longitude: draftLongitude)
    }

    private func seedDrafts() {
        draftTime = record.observedAt
        draftLocation = record.location
        draftLatitude = record.latitude
        draftLongitude = record.longitude
    }

    private func save() {
        var updated = record
        updated.observedAt = draftTime
        updated.location = draftLocation
        updated.latitude = draftLatitude
        updated.longitude = draftLongitude
        onSave(updated)
        dismiss()
    }
}
