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
    @State private var showSaveToast = false

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
        .overlay {
            if showSaveToast {
                SavedCardToast()
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
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
            guard !insertedIDs.isEmpty, store.highlightedRecordID == nil, !hasShownRecordTip else { return }

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
        .onChange(of: store.highlightedRecordID) { _, id in
            guard id != nil else { return }
            hasShownRecordTip = true
            showRecordTip = false
            withAnimation(.easeOut(duration: 0.18)) {
                selectedTab = .library
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                showSaveToast = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSaveToast = false
                    }
                }
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await MainActor.run {
                    if store.highlightedRecordID == id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            store.highlightedRecordID = nil
                        }
                    }
                }
            }
        }
    }
}

private struct SavedCardToast: View {
    @State private var animate = false

    private let colors: [Color] = [
        AppTheme.kelp,
        AppTheme.seaGlass,
        AppTheme.shell,
        AppTheme.sand,
        AppTheme.ink
    ]

    var body: some View {
        ZStack {
            ForEach(0..<26, id: \.self) { index in
                RoundedRectangle(cornerRadius: index.isMultiple(of: 3) ? 4 : 3, style: .continuous)
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 3) ? 8 : 7, height: index.isMultiple(of: 3) ? 8 : 17)
                    .offset(x: animate ? xOffset(for: index) : 0, y: animate ? yOffset(for: index) : 0)
                    .rotationEffect(.degrees(animate ? Double(index * 35) : 0))
                    .opacity(animate ? 0 : 1)
                    .scaleEffect(animate ? 0.82 : 0.2)
            }

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                Text("身份卡已保存")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
            .shadow(color: AppTheme.ink.opacity(0.12), radius: 18, x: 0, y: 9)
            .scaleEffect(animate ? 1 : 0.88)
        }
        .frame(width: 260, height: 220)
        .onAppear {
            withAnimation(.easeOut(duration: 1.05)) {
                animate = true
            }
        }
    }

    private func xOffset(for index: Int) -> CGFloat {
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return direction * CGFloat(26 + (index % 7) * 15)
    }

    private func yOffset(for index: Int) -> CGFloat {
        -CGFloat(36 + (index % 6) * 15)
    }
}

#Preview {
    ContentView()
        .environmentObject(EncounterStore())
}
