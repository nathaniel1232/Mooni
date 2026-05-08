import WidgetKit
import SwiftUI

// MARK: - Entry

struct FriendsSleepEntry: TimelineEntry {
    let date: Date
    let data: FriendsWidgetData
}

// MARK: - Provider

struct FriendsSleepProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendsSleepEntry {
        FriendsSleepEntry(date: Date(), data: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendsSleepEntry) -> Void) {
        completion(FriendsSleepEntry(date: Date(), data: FriendsWidgetStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendsSleepEntry>) -> Void) {
        let now = Date()
        let entry = FriendsSleepEntry(date: now, data: FriendsWidgetStore.read())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Entry View

struct FriendsSleepWidgetEntryView: View {
    let entry: FriendsSleepEntry

    var body: some View {
        FriendsSleepWidgetView(data: entry.data)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .containerBackground(for: .widget) {
                SleepWidgetBackground()
            }
    }
}

// MARK: - Widget

struct MooniFriendsSleepWidget: Widget {
    let kind: String = "MooniFriendsSleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FriendsSleepProvider()) { entry in
            FriendsSleepWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mooni Sleep Circle")
        .description("Compare your night with your friends.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Friends · Medium", as: .systemMedium) {
    MooniFriendsSleepWidget()
} timeline: {
    FriendsSleepEntry(date: .now, data: .sample)
}
