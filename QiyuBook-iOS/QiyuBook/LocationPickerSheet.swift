import CoreLocation
import MapKit
import SwiftUI

struct LocationSelection {
    var name: String
    var coordinate: CLLocationCoordinate2D
}

struct LocationSearchResult: Identifiable {
    let id = UUID()
    var mapItem: MKMapItem
}

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var selectedName = "地图选点"
    @State private var isResolving = false
    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    let onSelect: (LocationSelection) -> Void

    init(initialCoordinate: CLLocationCoordinate2D?, onSelect: @escaping (LocationSelection) -> Void) {
        let coordinate = initialCoordinate ?? CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        _selectedCoordinate = State(initialValue: coordinate)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $position) {
                        Marker("选点", coordinate: selectedCoordinate)
                    }
                    .mapStyle(.standard)
                    .onTapGesture { point in
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        selectedCoordinate = coordinate
                        Task {
                            await resolveName(for: coordinate)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    if isSearching || !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isSearching ? "正在搜索" : "搜索结果")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.faintText)

                            ForEach(searchResults.prefix(4)) { result in
                                Button {
                                    selectSearchResult(result)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundStyle(AppTheme.kelp)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.mapItem.name ?? "未命名地点")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.ink)
                                                .lineLimit(1)
                                            Text(result.mapItem.placemark.displayName ?? "")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.line, lineWidth: 1)
                        )
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(AppTheme.kelp)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isResolving ? "正在识别地点" : selectedName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text(String(format: "%.5f, %.5f", selectedCoordinate.latitude, selectedCoordinate.longitude))
                                .font(.caption)
                                .foregroundStyle(AppTheme.faintText)
                        }
                    }

                    Button {
                        onSelect(LocationSelection(name: selectedName, coordinate: selectedCoordinate))
                        dismiss()
                    } label: {
                        Text("使用这个地点")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding(18)
                .background(AppTheme.card)
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索地点或潜点")
            .onSubmit(of: .search) {
                Task {
                    await searchPlaces()
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard newValue.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    guard !Task.isCancelled else { return }
                    await searchPlaces()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                await resolveName(for: selectedCoordinate)
            }
        }
    }

    @MainActor
    private func searchPlaces() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let items = try await globalSearchItems(for: query)
            searchResults = deduplicated(items).prefix(6).map { LocationSearchResult(mapItem: $0) }
        } catch {
            searchResults = []
        }
    }

    private func globalSearchItems(for query: String) async throws -> [MKMapItem] {
        let queries = expandedSearchQueries(for: query)
        var items: [MKMapItem] = []

        for searchQuery in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchQuery
            request.resultTypes = [.address, .pointOfInterest]
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )

            if let response = try? await MKLocalSearch(request: request).start() {
                items.append(contentsOf: response.mapItems)
            }
        }

        for searchQuery in queries {
            if let placemarks = try? await CLGeocoder().geocodeAddressString(searchQuery) {
                items.append(contentsOf: placemarks.map { placemark in
                    MKMapItem(placemark: MKPlacemark(placemark: placemark))
                })
            }
        }

        return items
    }

    private func expandedSearchQueries(for query: String) -> [String] {
        var queries = [query]
        let zhLocale = Locale(identifier: "zh_Hans")
        let enLocale = Locale(identifier: "en_US")

        for regionCode in Locale.Region.isoRegions.map(\.identifier) {
            guard
                let zhName = zhLocale.localizedString(forRegionCode: regionCode),
                query.contains(zhName),
                let enName = enLocale.localizedString(forRegionCode: regionCode)
            else {
                continue
            }

            let translated = query.replacingOccurrences(of: zhName, with: enName)
            if translated != query {
                queries.append(translated)
            }
        }

        return Array(NSOrderedSet(array: queries)) as? [String] ?? queries
    }

    private func deduplicated(_ items: [MKMapItem]) -> [MKMapItem] {
        var seen = Set<String>()
        return items.filter { item in
            let coordinate = item.placemark.coordinate
            let key = "\(item.name ?? item.placemark.title ?? "")-\(String(format: "%.3f", coordinate.latitude))-\(String(format: "%.3f", coordinate.longitude))"
            return seen.insert(key).inserted
        }
    }

    @MainActor
    private func selectSearchResult(_ result: LocationSearchResult) {
        let coordinate = result.mapItem.placemark.coordinate
        selectedCoordinate = coordinate
        selectedName = result.mapItem.placemark.displayName ?? result.mapItem.name ?? "地图选点"
        searchText = selectedName
        searchResults = []
        position = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        ))
    }

    @MainActor
    private func resolveName(for coordinate: CLLocationCoordinate2D) async {
        isResolving = true
        defer { isResolving = false }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            selectedName = placemarks.first?.displayName ?? "地图选点"
        } catch {
            selectedName = "地图选点"
        }
    }
}

private extension CLPlacemark {
    var displayName: String? {
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
