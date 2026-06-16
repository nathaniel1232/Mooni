import SwiftUI

/// Hidden developer menu (unlocked by 20 taps on the paywall owl). Lets you
/// fabricate a tracked night and jump straight into the morning flow, sleep
/// story, or night analytics without waiting for a real night to be recorded.
struct DeveloperMenuView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var storyEntry: SleepEntry?
    @State private var analyticsEntry: SleepEntry?
    @State private var showMarketingVideo = false
    @State private var showMarketingPoster = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if let message {
                            banner(message)
                        }

                        section("Simulate") {
                            devRow("moon.stars.fill", "Simulate a tracked night",
                                   "Fabricate last night — scored, with a check-in",
                                   tint: MooniColor.accent) {
                                let e = simulateNight()
                                flash("Added a night: \(e.formattedDuration), score \(e.score)")
                            }
                            devRow("sun.and.horizon.fill", "Open morning check-in",
                                   "Reset today and launch the check-in flow",
                                   tint: MooniColor.warning) {
                                triggerMorningCheckIn()
                            }
                        }

                        section("Jump to a screen") {
                            devRow("sparkles", "Open Sleep Story",
                                   "Play the reveal for your latest night",
                                   tint: MooniColor.accentSoft) {
                                storyEntry = ensureEntry()
                            }
                            devRow("waveform.path.ecg", "Open Night Analytics",
                                   "The full hormone / cycle read-out",
                                   tint: MooniColor.success) {
                                analyticsEntry = ensureEntry()
                            }
                        }

                        section("Marketing") {
                            devRow("play.rectangle.fill", "Start Marketing Video",
                                   "Auto-looping reel for TikTok / Reels / App Store",
                                   tint: MooniColor.accent) {
                                showMarketingVideo = true
                            }
                            devRow("photo.fill", "Marketing Poster",
                                   "Screenshot-ready App Store / social promo",
                                   tint: MooniColor.accentSoft) {
                                showMarketingPoster = true
                            }
                        }

                        section("State") {
                            devRow(subscriptionManager.isPro ? "lock.open.fill" : "crown.fill",
                                   subscriptionManager.isPro ? "Turn Pro OFF" : "Turn Pro ON",
                                   "Toggle the developer Pro override",
                                   tint: MooniColor.success) {
                                if subscriptionManager.isPro {
                                    subscriptionManager.disableDevPro()
                                    flash("Pro disabled")
                                } else {
                                    subscriptionManager.enableDevPro()
                                    flash("Pro enabled")
                                }
                            }
                            devRow("trash", "Clear today's night",
                                   "Remove today's entry + its check-in",
                                   tint: MooniColor.danger) {
                                clearToday()
                                flash("Cleared today's night")
                            }
                            devRow("lock.fill", "Lock developer menu",
                                   "Hide this menu again (re-unlock from the paywall)",
                                   tint: MooniColor.textMuted) {
                                DeveloperMode.shared.lock()
                                dismiss()
                            }
                        }

                        Text("Unlocked via 20 taps on the paywall owl.")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(MooniColor.accent)
                }
            }
            .fullScreenCover(item: $storyEntry) { entry in
                SleepStoryView(
                    context: SleepStoryContext(appState: appState, entry: entry),
                    onFinished: { storyEntry = nil }
                )
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
            }
            .fullScreenCover(item: $analyticsEntry) { entry in
                NightAnalyticsView(entry: entry, onClose: { analyticsEntry = nil })
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .fullScreenCover(isPresented: $showMarketingVideo) {
                MarketingVideoView()
            }
            .fullScreenCover(isPresented: $showMarketingPoster) {
                MarketingPosterView()
            }
        }
    }

    // MARK: - UI pieces

    private func banner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(MooniColor.success)
            Text(text)
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(MooniColor.success.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(MooniFont.caption(11))
                .tracking(1.4)
                .foregroundColor(MooniColor.textMuted)
                .padding(.leading, 4)
            content()
        }
    }

    private func devRow(_ icon: String, _ title: String, _ subtitle: String,
                        tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            MooniCard(padding: 14) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(tint)
                        .frame(width: 38, height: 38)
                        .background(tint.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                        Text(subtitle)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func flash(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) { message = text }
    }

    // MARK: - Actions

    /// Builds a realistic last-night entry (scored, with a generated check-in)
    /// so history / analytics / home all have something to show immediately.
    @discardableResult
    private func simulateNight() -> SleepEntry {
        // Most recent target wake before now, with a little jitter.
        var wake = todayAt(appState.targetWakeTime)
        if wake > Date() { wake = wake.addingTimeInterval(-86_400) }
        wake = wake.addingTimeInterval(Double(Int.random(in: -30...30)) * 60)

        let hours = max(4.0, min(10.0, appState.goalHours + Double.random(in: -1.2...0.6)))
        let bed = wake.addingTimeInterval(-hours * 3600)

        let quality: SleepEntry.Quality = [.great, .good, .good, .okay].randomElement()!
        let mood: SleepEntry.Mood = [.energized, .okay, .tired].randomElement()!

        let entry = appState.logSleep(
            bedtime: bed, wakeTime: wake, quality: quality, mood: mood,
            notes: "Developer-simulated night", routineCompleted: Bool.random()
        )

        // A matching check-in so the analytics tie-ins + answers grid populate.
        let caffeineCount = Int.random(in: 0...3)
        let lastCaffeine = caffeineCount >= 1 ? todayAt(hour: Int.random(in: 13...18), minute: 0) : nil
        let lateCaffeine = lastCaffeine.map { Calendar.current.component(.hour, from: $0) >= 15 } ?? false

        let checkIn = MorningCheckIn(
            date: entry.wakeTime,
            feeling: [.great, .okay, .tired].randomElement()!,
            wakeUps: [.none, .once, .fewTimes].randomElement()!,
            dreams: [.yes, .no, .notSure].randomElement()!,
            getOutOfBedDifficulty: [.easy, .normal, .hard].randomElement()!,
            lateCaffeine: lateCaffeine,
            minutesToFallAsleep: Int.random(in: 4...35),
            minutesPhoneDownToSleep: Int.random(in: 1...20),
            caffeineCount: caffeineCount,
            lastCaffeineTime: lastCaffeine,
            lastMealTime: todayAt(hour: Int.random(in: 18...21), minute: 0).addingTimeInterval(-86_400),
            lateHeavyMeal: Bool.random(),
            alcoholDrinks: [0, 0, 1, 2].randomElement()!,
            exerciseTime: ExerciseTiming.allCases.randomElement()!,
            napMinutes: [0, 0, 0, 20].randomElement()!,
            stressLevel: StressLevel.allCases.randomElement()!,
            roomFeel: RoomTemp.allCases.randomElement()!
        )
        return appState.completeMorningCheckIn(checkIn) ?? entry
    }

    /// Wipes today's night and reopens the morning check-in on a fresh entry.
    private func triggerMorningCheckIn() {
        clearToday()
        appState.seedMissedNightEntry()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            appState.showMorningCheckIn = true
        }
    }

    /// The latest entry, fabricating one first if there is none yet.
    private func ensureEntry() -> SleepEntry {
        appState.lastEntry ?? simulateNight()
    }

    private func clearToday() {
        let key = Date().dayKey
        appState.entries.removeAll { $0.dayKey == key }
        MorningCheckInStore.clear(for: key)
    }

    // MARK: - Date helpers

    private func todayAt(_ template: Date) -> Date {
        let c = Calendar.current.dateComponents([.hour, .minute], from: template)
        return todayAt(hour: c.hour ?? 7, minute: c.minute ?? 0)
    }

    private func todayAt(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

#Preview {
    DeveloperMenuView()
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
