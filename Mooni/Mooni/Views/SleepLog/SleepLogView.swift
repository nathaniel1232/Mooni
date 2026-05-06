import SwiftUI

struct SleepLogView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        logCTA
                        history
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showLogSheet) {
                LogSleepSheet()
            }
        }
    }

    private var logCTA: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "bed.double.fill").foregroundColor(MooniColor.accent)
                    Text("Log a night")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                }
                Text("Tell us when you slept and how it felt. \(appState.pet.name) reacts to every night.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)

                PrimaryButton(title: "Log sleep", icon: "plus") {
                    showLogSheet = true
                }
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        if appState.entries.isEmpty {
            MooniCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your nights")
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("No history yet — your first night will appear here.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your nights")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                    .padding(.leading, 6)

                ForEach(appState.entries.sorted(by: { $0.wakeTime > $1.wakeTime })) { entry in
                    NightRow(entry: entry)
                }
            }
        }
    }
}

private struct NightRow: View {
    let entry: SleepEntry

    var body: some View {
        MooniCard(padding: 16) {
            HStack(spacing: 16) {
                SleepScoreRing(score: entry.score, size: 64, lineWidth: 7)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.wakeTime, format: .dateTime.weekday(.wide).day().month())
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(entry.formattedDuration)
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                    HStack(spacing: 8) {
                        Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                        Text("• \(entry.quality.emoji) \(entry.quality.label)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Log Sheet
struct LogSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var bedtime: Date = Date.todayAt(hour: 23, minute: 0).addingTimeInterval(-86400)
    @State private var wakeTime: Date = Date.todayAt(hour: 7, minute: 0)
    @State private var quality: SleepEntry.Quality = .good
    @State private var mood: SleepEntry.Mood = .okay
    @State private var notes: String = ""
    @State private var routineCompleted: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        timeSection
                        qualitySection
                        moodSection
                        routineSection
                        notesSection

                        PrimaryButton(title: "Save", icon: "checkmark") {
                            appState.logSleep(
                                bedtime: bedtime,
                                wakeTime: wakeTime,
                                quality: quality,
                                mood: mood,
                                notes: notes,
                                routineCompleted: routineCompleted || appState.routine.isFullyCompleted
                            )
                            dismiss()
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                if bedtime > wakeTime {
                    bedtime = Calendar.current.date(byAdding: .day, value: -1, to: bedtime) ?? bedtime
                }
                routineCompleted = appState.routine.isFullyCompleted
            }
        }
    }

    private var timeSection: some View {
        MooniCard {
            VStack(spacing: 14) {
                timeRow(title: "Bedtime",  icon: "moon.fill",      selection: $bedtime)
                Divider().background(Color.white.opacity(0.1))
                timeRow(title: "Wake up",  icon: "sun.max.fill",   selection: $wakeTime)

                HStack {
                    Image(systemName: "clock").foregroundColor(MooniColor.textSecondary)
                    Text("Duration: \(durationString)")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func timeRow(title: String, icon: String, selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(MooniColor.accent).frame(width: 24)
            Text(title)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden().colorScheme(.dark)
        }
    }

    private var qualitySection: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quality")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                HStack(spacing: 8) {
                    ForEach(SleepEntry.Quality.allCases) { q in
                        chip(label: "\(q.emoji) \(q.label)", selected: quality == q) {
                            quality = q
                        }
                    }
                }
            }
        }
    }

    private var moodSection: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood after waking")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                HStack(spacing: 8) {
                    ForEach(SleepEntry.Mood.allCases) { m in
                        chip(label: "\(m.emoji) \(m.label)", selected: mood == m) {
                            mood = m
                        }
                    }
                }
            }
        }
    }

    private var routineSection: some View {
        MooniCard {
            Toggle(isOn: $routineCompleted) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completed wind-down")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Bonus growth if Luna had a wind-down")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }
            .tint(MooniColor.accent)
        }
    }

    private var notesSection: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                TextField("", text: $notes, prompt: Text("Anything to remember about this night?")
                    .foregroundColor(MooniColor.textMuted), axis: .vertical)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(MooniFont.caption(13))
                .foregroundColor(selected ? MooniColor.background : MooniColor.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(selected ? MooniColor.accent : Color.white.opacity(0.07))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var durationString: String {
        let interval = max(0, wakeTime.timeIntervalSince(bedtime))
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }
}

#Preview {
    SleepLogView().environmentObject(AppState.preview)
}
