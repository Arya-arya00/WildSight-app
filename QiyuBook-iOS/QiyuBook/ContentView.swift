import SwiftUI

enum AppTab: Hashable {
    case record
    case library
}

struct ContentView: View {
    @EnvironmentObject private var store: EncounterStore
    @AppStorage("hasShownRecordTipV2") private var hasShownRecordTip = false
    @State private var selectedTab: AppTab = .record
    @State private var knownRecordIDs: Set<UUID> = []
    @State private var showRecordTip = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RecordHomeView()
            }
            .tabItem {
                Label("认识", systemImage: "sparkles")
            }
            .tag(AppTab.record)

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("记录", systemImage: "square.grid.2x2")
            }
            .tag(AppTab.library)
        }
        .tint(AppTheme.ink)
        .overlay(alignment: .bottomTrailing) {
            if showRecordTip {
                Button {
                    hasShownRecordTip = true
                    showRecordTip = false
                    selectedTab = .library
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.right")
                        Text("可在「记录」里查看")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                    .shadow(color: AppTheme.ink.opacity(0.10), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 22)
                .padding(.bottom, 58)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            knownRecordIDs = Set(store.records.map(\.id))
        }
        .onChange(of: store.records.map(\.id)) { _, ids in
            let newIDs = Set(ids)
            let insertedIDs = newIDs.subtracting(knownRecordIDs)
            knownRecordIDs = newIDs
            guard !insertedIDs.isEmpty, !hasShownRecordTip else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                showRecordTip = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    hasShownRecordTip = true
                    withAnimation(.easeOut(duration: 0.2)) {
                        showRecordTip = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EncounterStore())
}
