//
//  MooniSleepWidget.swift
//  MooniSleepWidget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SleepWidgetEntry: TimelineEntry {
    let date: Date
    let data: SleepWidgetData
}

// MARK: - Timeline Provider

/// Reads from `WidgetDataStore` (mock today, App-Group-backed once you flip
/// the switch in `SleepWidgetData.swift`). Refreshes hourly so the widget
/// stays roughly in sync with the most recent night written by the app.
struct SleepWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SleepWidgetEntry {
        SleepWidgetEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepWidgetEntry) -> Void) {
        completion(SleepWidgetEntry(date: Date(), data: WidgetDataStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepWidgetEntry>) -> Void) {
        let now = Date()
        let entry = SleepWidgetEntry(date: now, data: WidgetDataStore.read())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Entry View (size router)

struct MooniSleepWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SleepWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumSleepWidgetView(data: entry.data)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            default:
                SmallSleepWidgetView(data: entry.data)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }
        }
        .containerBackground(for: .widget) {
            SleepWidgetBackground()
        }
    }
}

// MARK: - Widget Definition

struct MooniSleepWidget: Widget {
    let kind: String = "MooniSleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SleepWidgetProvider()) { entry in
            MooniSleepWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mooni Sleep")
        .description("Your latest sleep score, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MooniSleepWidget()
} timeline: {
    SleepWidgetEntry(date: .now, data: .sample)
    SleepWidgetEntry(date: .now, data: SleepWidgetData(
        score: 92, quality: "Excellent", sleepDuration: "8h 12m",
        sleepStart: "10:48 PM", wakeTime: "7:00 AM", energyScore: 88, updatedAt: .now
    ))
    SleepWidgetEntry(date: .now, data: SleepWidgetData(
        score: 44, quality: "Bad", sleepDuration: "5h 02m",
        sleepStart: "1:18 AM", wakeTime: "6:20 AM", energyScore: 38, updatedAt: .now
    ))
}

#Preview("Medium", as: .systemMedium) {
    MooniSleepWidget()
} timeline: {
    SleepWidgetEntry(date: .now, data: .sample)
}
