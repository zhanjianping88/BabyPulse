//
//  ContentView.swift
//  BabyPulse
//
//  Created by Codex on 2026/3/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum SharedTrackerSheet: Identifiable {
    case sharedTracker

    var id: String { "shared-tracker" }
}

struct ContentView: View {
    @EnvironmentObject private var store: BabyStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var reminderStore: ReminderStore
    @State private var selectedTab: AppTab = .home
    @State private var destination: QuickLogDestination?
    @State private var sharedTrackerSheet: SharedTrackerSheet?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                destination: $destination,
                selectedTab: $selectedTab,
                sharedTrackerSheet: $sharedTrackerSheet
            )
                .tabItem {
                    Label("Home", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.home)

            TimelineScreen()
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.timeline)

            StatsScreen()
                .tabItem {
                    Label("Stats", systemImage: "waveform.path.ecg")
                }
                .tag(AppTab.stats)
        }
        .tint(.pulseAccent)
        .preferredColorScheme(.dark)
        .sheet(item: $destination) { item in
            switch item {
            case .sleep:
                SleepScreen()
            case .feed:
                FeedScreen()
                    .presentationDetents([.fraction(0.9), .large])
                    .presentationDragIndicator(.visible)
            case .diaper:
                DiaperScreen()
                    .presentationDetents([.large])
            }
        }
        .sheet(item: $sharedTrackerSheet) { _ in
            SharedTrackerScreen()
        }
        .sheet(item: $entitlementStore.presentedFeature) { feature in
            PaywallScreen(feature: feature)
        }
        .background(Color.pulseBackground.ignoresSafeArea())
        .task {
            reminderStore.refreshAuthorizationStatus()
            reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
        }
        .onReceive(store.$feedLogs) { _ in
            reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
        }
        .onReceive(store.$activeSleepStart) { _ in
            reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
        }
        .onReceive(entitlementStore.$hasPro) { hasPro in
            reminderStore.syncNotifications(using: store, hasPro: hasPro)
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: BabyStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Binding var destination: QuickLogDestination?
    @Binding var selectedTab: AppTab
    @Binding var sharedTrackerSheet: SharedTrackerSheet?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if entitlementStore.hasPro == false {
                        upgradeCard
                    }
                    if store.activeSleepStart != nil {
                        activeSleepCard
                    }
                    quickActions
                    timelinePreview
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(Color.pulseBackground.ignoresSafeArea())
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("BabyPulse Pro", systemImage: "waveform")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))

                Spacer()

                Button {
                    sharedTrackerSheet = .sharedTracker
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(width: 40, height: 40)
                        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    entitlementStore.presentPaywall(for: .smartReminders)
                } label: {
                    Image(systemName: entitlementStore.hasPro ? "checkmark.seal.fill" : "crown.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(entitlementStore.hasPro ? Color.pulseTeal : Color.pulseAccent)
                        .frame(width: 40, height: 40)
                        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Text("TODAY SLEEP")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.2)

            Text(store.todaySleepDuration().dashboardText)
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var upgradeCard: some View {
        Button {
            entitlementStore.presentPaywall(for: .smartReminders)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("BABYPULSE PRO", systemImage: "crown.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseAccent)
                        .tracking(1.1)
                    Spacer()
                    Text("$2.99 / week")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("Unlock smart reminders, advanced stats, and full history.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Text("Shared tracker codes stay free. Pro adds local reminders and deeper insights.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.pulseAccent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var activeSleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("SLEEPING NOW", systemImage: "moon.stars.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pulseTeal)
                    .tracking(1.1)

                Spacer()

                Button("Open") {
                    destination = .sleep
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.pulseAccent, in: Capsule())
            }

            if let activeSleepStart = store.activeSleepStart {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date.timeIntervalSince(activeSleepStart).clockText)
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Text("Started \(RelativeDateTimeFormatter().localizedString(for: activeSleepStart, relativeTo: .now))")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.pulseCard, Color.pulseCard.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.pulseTeal.opacity(0.28), lineWidth: 1)
        )
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeActionButton(
                title: "Sleep",
                icon: "moon.fill",
                color: .pulseAccent,
                isPrimary: true
            ) {
                destination = .sleep
            }

            HomeActionButton(
                title: "Feed",
                icon: "cup.and.saucer.fill",
                color: .pulseTeal
            ) {
                destination = .feed
            }

            HomeActionButton(
                title: "Diaper",
                icon: "drop.triangle.fill",
                color: .pulseOrange
            ) {
                destination = .diaper
            }
        }
    }

    private var timelinePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TIMELINE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.2)

            VStack(spacing: 0) {
                ForEach(Array(store.timeline(limit: 4).enumerated()), id: \.element.id) { index, item in
                    TimelineRow(item: item)
                        .padding(.vertical, 14)

                    if index < 3 {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

private struct SleepScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pulseBackground.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    if let activeSleepStart = store.activeSleepStart {
                        Text("Sleeping now")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.pulseTeal)

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(activeSleepStart).clockText)
                                .font(.system(size: 78, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }

                        Button {
                            store.endSleep()
                            dismiss()
                        } label: {
                            Label("End Sleep", systemImage: "stop.circle.fill")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(PulsePrimaryButtonStyle())
                    } else {
                        Text("Ready for sleep")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.pulseMuted)

                        Text("00:00")
                            .font(.system(size: 78, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .monospacedDigit()

                        Button {
                            store.startSleep()
                        } label: {
                            Label("Start Sleep", systemImage: "moon.circle.fill")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(PulsePrimaryButtonStyle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Label("BabyPulse Pro", systemImage: "waveform")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseAccent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
    }
}

private struct FeedScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: FeedType = .bottle
    @State private var amountML: Int = 120

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Feed")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Select feeding method to log activity")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.pulseMuted)
                    }

                    HStack(spacing: 12) {
                        ForEach(FeedType.allCases) { type in
                            SelectablePill(
                                title: type.title,
                                icon: type.icon,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }

                    VStack(spacing: 18) {
                        Text("AMOUNT TO LOG")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.pulseMuted)
                            .tracking(1.8)

                        HStack {
                            StepperButton(symbol: "minus") {
                                amountML = max(30, amountML - 30)
                            }

                            Spacer()

                            VStack(spacing: 4) {
                                Text("\(amountML)")
                                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color.pulseAccent)
                                    .monospacedDigit()
                                Text("ML")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.pulseMuted)
                            }

                            Spacer()

                            StepperButton(symbol: "plus") {
                                amountML = min(300, amountML + 30)
                            }
                        }

                        Text("Defaulting to current time")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.pulseTeal)

                        Button {
                            store.addFeed(type: selectedType, amountML: amountML)
                            dismiss()
                        } label: {
                            Text("SAVE")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                        .buttonStyle(PulsePrimaryButtonStyle())
                    }
                    .padding(20)
                    .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    if let lastFeed = store.lastFeed {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.pulsePeach)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.white)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("LAST FEED")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.pulseMuted)
                                Text("\(RelativeDateTimeFormatter().localizedString(for: lastFeed.date, relativeTo: .now)) • \(lastFeed.amountML)mL \(lastFeed.type.title)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}

private struct DiaperScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Label("BabyPulse Pro", systemImage: "waveform")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseAccent)

                    Text("QUICK LOG")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseMuted)
                        .tracking(1.2)

                    Text("Diaper Change")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(spacing: 14) {
                        ForEach(DiaperType.allCases) { type in
                            Button {
                                store.addDiaper(type: type)
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle().fill(color(for: type).opacity(0.15))
                                        Image(systemName: type.icon)
                                            .foregroundStyle(color(for: type))
                                    }
                                    .frame(width: 56, height: 56)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(type.title)
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("INSTANT RECORD")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.pulseMuted)
                                            .tracking(1.3)
                                    }

                                    Spacer()
                                }
                                .padding(18)
                                .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("DAILY SUMMARY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseMuted)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        summaryCard(value: String(format: "%02d", store.todayDiaperCount()), title: "TOTAL TODAY", accent: .pulseTeal, icon: "calendar")
                        VStack(spacing: 12) {
                            summaryCard(value: "\(store.todayDiaperCount(for: .wet))", title: "WET", accent: .pulseTeal, icon: "drop.fill")
                            summaryCard(value: "\(store.todayDiaperCount(for: .dirty))", title: "DIRTY", accent: .pulseOrange, icon: "sparkles.rectangle.stack.fill")
                        }
                    }

                    if let lastDiaper = store.lastDiaper {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Last Change")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.pulseAccent)
                            }

                            Text(RelativeDateTimeFormatter().localizedString(for: lastDiaper.date, relativeTo: .now))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.pulseMuted)

                            HStack(spacing: 8) {
                                capsuleText(lastDiaper.type.title.uppercased())
                                capsuleText(lastDiaper.date.formatted(date: .omitted, time: .shortened))
                            }
                        }
                        .padding(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.pulseAccent.opacity(0.75), lineWidth: 1)
                        )
                    }
                }
                .padding(20)
            }
            .background(Color.pulseBackground.ignoresSafeArea())
        }
    }

    private func color(for type: DiaperType) -> Color {
        switch type {
        case .wet: .pulseTeal
        case .dirty: .pulseOrange
        case .mixed: .pulseAccent
        }
    }

    private func summaryCard(value: String, title: String, accent: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func capsuleText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: Capsule())
    }
}

private struct TimelineScreen: View {
    @EnvironmentObject private var store: BabyStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var editorDestination: TimelineEditorDestination?

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleTimeline) { item in
                    TimelineRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            switch item.kind {
                            case .sleep:
                                if item.title == "Nap" {
                                    editorDestination = .sleep(item.id)
                                }
                            case .feed:
                                editorDestination = .feed(item.id)
                            case .diaper:
                                editorDestination = .diaper(item.id)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteTimelineItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.pulseBackground)
                        .listRowSeparatorTint(Color.white.opacity(0.06))
                }

                if entitlementStore.hasPro == false, lockedTimelineCount > 0 {
                    lockedHistoryCard
                        .listRowBackground(Color.pulseBackground)
                        .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Timeline")
            .sheet(item: $editorDestination) { destination in
                switch destination {
                case let .sleep(id):
                    if let session = store.sleepSession(id: id) {
                        SleepEditorScreen(session: session)
                    }
                case let .feed(id):
                    if let log = store.feedLog(id: id) {
                        FeedEditorScreen(log: log)
                    }
                case let .diaper(id):
                    if let log = store.diaperLog(id: id) {
                        DiaperEditorScreen(log: log)
                    }
                }
            }
        }
    }

    private var visibleTimeline: [TimelineItem] {
        guard entitlementStore.hasPro == false else { return store.timeline() }
        let cutoff = Calendar.current.date(byAdding: .day, value: -entitlementStore.freeHistoryDays, to: .now) ?? .now
        return store.timeline().filter { $0.date >= cutoff }
    }

    private var lockedTimelineCount: Int {
        store.timeline().count - visibleTimeline.count
    }

    private var lockedHistoryCard: some View {
        Button {
            entitlementStore.presentPaywall(for: .unlimitedHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label("PRO REQUIRED", systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pulseAccent)
                    .tracking(1.2)
                Text("Unlock \(lockedTimelineCount) older records")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Free includes the latest \(entitlementStore.freeHistoryDays) days. Upgrade for full history.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct StatsScreen: View {
    @EnvironmentObject private var store: BabyStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var reminderStore: ReminderStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Simple Stats")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    statsCard(title: "Sleep Today", value: store.todaySleepDuration().dashboardText, subtitle: "Across naps and current sleep", accent: .pulseAccent)
                    if entitlementStore.hasPro {
                        remindersCard
                        statsCard(title: "Feed Today", value: "\(store.todayFeedTotal()) mL", subtitle: "Quick total from logged feeds", accent: .pulseTeal)
                        statsCard(title: "Diapers Today", value: "\(store.todayDiaperCount())", subtitle: "\(store.todayDiaperCount(for: .wet)) wet • \(store.todayDiaperCount(for: .dirty)) dirty • \(store.todayDiaperCount(for: .mixed)) mixed", accent: .pulseOrange)
                        last24HoursCard
                        trendCard
                    } else {
                        freeStatsPreview
                    }
                }
                .padding(20)
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Stats")
        }
    }

    private func statsCard(title: String, value: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.4)

            Text(value)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var last24HoursCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LAST 24 HOURS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.4)

            HStack(spacing: 12) {
                microStat(value: "\(store.sleepSessionsCount(inLastHours: 24))", title: "SLEEPS", accent: .pulseAccent)
                microStat(value: "\(store.feedCount(inLastHours: 24))", title: "FEEDS", accent: .pulseTeal)
                microStat(value: "\(store.diaperCount(inLastHours: 24))", title: "CHANGES", accent: .pulseOrange)
            }

            Text("Average feed: \(store.averageFeedAmount(inLastHours: 24)) mL")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var freeStatsPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PRO INSIGHTS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseAccent)
                .tracking(1.4)

            Text("Unlock reminders, trends, and full history")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Free users keep shared tracker codes, basic logging, and recent history. Upgrade for local reminders and deeper patterns.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))

            Button("See Pro") {
                entitlementStore.presentPaywall(for: .advancedStats)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PulsePrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SMART REMINDERS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseTeal)
                        .tracking(1.4)

                    Text(reminderStore.authorizationDescription)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                Spacer()

                if reminderStore.authorizationStatus == .notDetermined || reminderStore.authorizationStatus == .denied {
                    Button(reminderStore.authorizationStatus == .denied ? "Open Settings" : "Enable") {
                        if reminderStore.authorizationStatus == .denied {
                            openNotificationSettings()
                        } else {
                            requestReminderAuthorization()
                        }
                    }
                    .frame(minWidth: 92)
                    .buttonStyle(PulseSecondaryButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Toggle("Feed reminders", isOn: feedReminderBinding)
                    .tint(.pulseTeal)

                reminderIntervalRow(
                    title: "Feed interval",
                    selection: $reminderStore.feedReminderHours,
                    options: [2, 3, 4],
                    suffix: "h"
                )

                Toggle("Sleep check-ins", isOn: sleepReminderBinding)
                    .tint(.pulseAccent)

                reminderIntervalRow(
                    title: "Sleep check interval",
                    selection: $reminderStore.sleepCheckMinutes,
                    options: [60, 90, 120],
                    suffix: "m"
                )
            }
            .disabled(reminderControlsDisabled)
            .opacity(reminderControlsDisabled ? 0.45 : 1)

            Text("Feed reminders trigger after the latest logged feed. Sleep check-ins trigger while a sleep timer is active.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onChange(of: reminderStore.feedReminderHours) { _ in
            reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
        }
        .onChange(of: reminderStore.sleepCheckMinutes) { _ in
            reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7 DAY TREND")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.4)

            HStack(spacing: 12) {
                microStat(value: store.sleepDuration(inLastDays: 7).dashboardText, title: "SLEEP", accent: .pulseAccent)
                microStat(value: "\(store.feedVolume(inLastDays: 7)) mL", title: "FEED", accent: .pulseTeal)
                microStat(value: "\(store.diaperCount(inLastHours: 24 * 7))", title: "DIAPERS", accent: .pulseOrange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func microStat(value: String, title: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .tracking(1.1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var feedReminderBinding: Binding<Bool> {
        Binding {
            reminderStore.feedRemindersEnabled
        } set: { value in
            if value && (reminderStore.authorizationStatus == .notDetermined || reminderStore.authorizationStatus == .denied) {
                requestReminderAuthorization {
                    reminderStore.feedRemindersEnabled = true
                    reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
                }
            } else {
                reminderStore.feedRemindersEnabled = value
                reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
            }
        }
    }

    private var sleepReminderBinding: Binding<Bool> {
        Binding {
            reminderStore.sleepCheckEnabled
        } set: { value in
            if value && (reminderStore.authorizationStatus == .notDetermined || reminderStore.authorizationStatus == .denied) {
                requestReminderAuthorization {
                    reminderStore.sleepCheckEnabled = true
                    reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
                }
            } else {
                reminderStore.sleepCheckEnabled = value
                reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
            }
        }
    }

    private func reminderIntervalRow(title: String, selection: Binding<Int>, options: [Int], suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pulseMuted)
                .tracking(1.2)

            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text("\(option)\(suffix)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(selection.wrappedValue == option ? Color.black.opacity(0.82) : Color.white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selection.wrappedValue == option ? Color.pulseAccent : Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var reminderControlsDisabled: Bool {
        let status = reminderStore.authorizationStatus
        return status != .authorized && status != .provisional
    }

    private func requestReminderAuthorization(onGranted: (() -> Void)? = nil) {
        Task {
            let granted = await reminderStore.requestAuthorization()
            if granted {
                onGranted?()
                reminderStore.syncNotifications(using: store, hasPro: entitlementStore.hasPro)
            }
        }
    }

    private func openNotificationSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }
}

private struct SharedTrackerScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss

    @State private var exportCode = ""
    @State private var importCode = ""
    @State private var message: String?
    @State private var pendingImportSummary: SharedTrackerImportSummary?
    @State private var pendingImportCode: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared Tracker")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Share your current baby log once, or join a tracker by pasting a shared code.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.pulseMuted)
                    }

                    shareSection
                    joinSection

                    Text("This is a one-time transfer. After import, both devices start from the same data but do not stay in sync automatically.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.68))
                }
                .padding(20)
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if exportCode.isEmpty {
                    regenerateExportCode()
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Shared Tracker", isPresented: Binding(
            get: { message != nil },
            set: { isPresented in
                if isPresented == false {
                    message = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                message = nil
            }
        } message: {
            Text(message ?? "")
        }
        .alert(
            "Replace current data?",
            isPresented: Binding(
                get: { pendingImportSummary != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingImportSummary = nil
                        pendingImportCode = nil
                    }
                }
            ),
            presenting: pendingImportSummary
        ) { summary in
            Button("Cancel", role: .cancel) {
                pendingImportSummary = nil
                pendingImportCode = nil
            }

            Button("Import and Replace", role: .destructive) {
                confirmImport(summary: summary)
            }
        } message: { summary in
            Text(confirmMessage(for: summary))
        }
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Share with partner")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Generate a code from your current sleep, feed, and diaper records. Your partner can paste it into their app.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))

            ScrollView(.vertical, showsIndicators: true) {
                Text(exportCode)
                    .textSelection(.enabled)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.pulseAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(minHeight: 180, maxHeight: 220)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            HStack(spacing: 12) {
                ShareLink(item: exportCode) {
                    Label("Share Code", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PulsePrimaryButtonStyle())

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = exportCode
                    message = "Shared code copied."
                    #else
                    message = "Copy is only available on iPhone."
                    #endif
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PulseSecondaryButtonStyle())
            }

            Button("Regenerate Code") {
                regenerateExportCode()
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Join shared tracker")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Paste a code from your partner. Importing replaces the data currently stored on this device.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))

            TextEditor(text: $importCode)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 170)
                .padding(12)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            Button {
                importSharedTracker()
            } label: {
                Label("Import and Replace", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PulsePrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func regenerateExportCode() {
        do {
            exportCode = try store.exportSharedTrackerCode()
        } catch {
            exportCode = ""
            message = "Unable to generate a shared code right now."
        }
    }

    private func importSharedTracker() {
        do {
            let summary = try store.previewSharedTrackerImport(importCode)
            pendingImportCode = importCode
            pendingImportSummary = summary
        } catch {
            message = error.localizedDescription
        }
    }

    private func confirmImport(summary: SharedTrackerImportSummary) {
        guard let pendingImportCode else { return }

        do {
            _ = try store.importSharedTrackerCode(pendingImportCode)
            importCode = ""
            pendingImportSummary = nil
            self.pendingImportCode = nil
            regenerateExportCode()
            message = "Imported \(summary.sleepSessions) sleeps, \(summary.feedLogs) feeds, and \(summary.diaperLogs) diaper changes."
        } catch {
            message = error.localizedDescription
        }
    }

    private func confirmMessage(for summary: SharedTrackerImportSummary) -> String {
        var lines = [
            "This will replace the data currently stored on this device.",
            "",
            "Incoming data:",
            "\(summary.sleepSessions) sleep sessions",
            "\(summary.feedLogs) feed logs",
            "\(summary.diaperLogs) diaper changes"
        ]

        if summary.hasActiveSleep {
            lines.append("1 active sleep timer")
        }

        return lines.joined(separator: "\n")
    }
}

private struct PaywallScreen: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @Environment(\.dismiss) private var dismiss

    let feature: PremiumFeature

    private let privacyPolicyURL = URL(string: "https://zhanjianping88.github.io/BabyPulse/privacy-policy.html")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private let allFeatures: [PremiumFeature] = [
        .unlimitedHistory,
        .advancedStats,
        .smartReminders
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Label("BABYPULSE PRO", systemImage: "crown.fill")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pulseAccent)

                    Text(feature.title)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(feature.subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))

                    VStack(spacing: 14) {
                        ForEach(allFeatures, id: \.rawValue) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(item == feature ? Color.pulseAccent : Color.pulseTeal)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(item.subtitle)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.68))
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("AUTO-RENEWING SUBSCRIPTION")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.pulseMuted)
                            .tracking(1.3)
                        Text("BabyPulse Pro Premium Weekly")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(entitlementStore.weeklyPriceText) / week")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("1-week subscription with automatic renewal. Best for proactive reminders and richer insight during the newborn stage.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    .padding(20)
                    .background(Color.pulseCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button(entitlementStore.hasPro ? "Premium Active" : purchaseButtonTitle) {
                        Task {
                            let purchased = await entitlementStore.purchaseWeekly()
                            if purchased {
                                dismiss()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PulsePrimaryButtonStyle())
                    .disabled(entitlementStore.isBusy || entitlementStore.hasPro)

                    if let storeErrorMessage = entitlementStore.storeErrorMessage {
                        Text(storeErrorMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.pulseOrange)
                    }

                    Button("Restore Purchases") {
                        Task {
                            await entitlementStore.restorePurchases()
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .disabled(entitlementStore.isBusy)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payment will be charged to your Apple Account at confirmation of purchase. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your App Store account settings.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.58))

                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: privacyPolicyURL)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.pulseAccent)

                            Link("Terms of Use", destination: termsOfUseURL)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.pulseAccent)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.pulseBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await entitlementStore.loadProductsIfNeeded()
        }
    }

    private var purchaseButtonTitle: String {
        switch entitlementStore.purchaseState {
        case .loadingProducts:
            "Loading Price..."
        case .purchasing:
            "Purchasing..."
        case .restoring:
            "Restoring..."
        case .idle:
            "Unlock Premium"
        }
    }
}

private struct SleepEditorScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss

    let session: SleepSession
    @State private var start: Date
    @State private var end: Date

    init(session: SleepSession) {
        self.session = session
        _start = State(initialValue: session.start)
        _end = State(initialValue: session.end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    DatePicker("Start", selection: $start)
                    DatePicker("End", selection: $end, in: start...)
                }

                Section {
                    Text("Total: \(end.timeIntervalSince(start).clockText)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Edit Sleep")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.updateSleep(id: session.id, start: start, end: end)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct FeedEditorScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss

    let log: FeedLog
    @State private var selectedType: FeedType
    @State private var amountML: Int
    @State private var date: Date

    init(log: FeedLog) {
        self.log = log
        _selectedType = State(initialValue: log.type)
        _amountML = State(initialValue: log.amountML)
        _date = State(initialValue: log.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Feed Type", selection: $selectedType) {
                        ForEach(FeedType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Amount") {
                    Stepper("\(amountML) mL", value: $amountML, in: 30...300, step: 30)
                }

                Section("Time") {
                    DatePicker("Logged At", selection: $date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Edit Feed")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.updateFeed(id: log.id, type: selectedType, amountML: amountML, date: date)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct DiaperEditorScreen: View {
    @EnvironmentObject private var store: BabyStore
    @Environment(\.dismiss) private var dismiss

    let log: DiaperLog
    @State private var selectedType: DiaperType
    @State private var date: Date

    init(log: DiaperLog) {
        self.log = log
        _selectedType = State(initialValue: log.type)
        _date = State(initialValue: log.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Diaper Type", selection: $selectedType) {
                        ForEach(DiaperType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Time") {
                    DatePicker("Logged At", selection: $date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pulseBackground.ignoresSafeArea())
            .navigationTitle("Edit Change")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.updateDiaper(id: log.id, type: selectedType, date: date)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TimelineRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(item.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.pulseMuted)
            }

            Spacer()

            Text(item.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private var color: Color {
        switch item.kind {
        case .sleep: .pulseAccent
        case .feed: .pulseTeal
        case let .diaper(type):
            switch type {
            case .wet: .pulseTeal
            case .dirty: .pulseOrange
            case .mixed: .pulseAccent
            }
        }
    }
}

private struct HomeActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(isPrimary ? Color.black.opacity(0.82) : Color.white.opacity(0.88))
            .padding(.vertical, 18)
            .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: some ShapeStyle {
        if isPrimary {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.pulseAccent, Color.pulseAccent.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color.pulseCard)
    }
}

private struct SelectablePill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(isSelected ? Color.pulseAccent : .white.opacity(0.8))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.pulseCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.pulseAccent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PulsePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black.opacity(0.82))
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.pulseAccent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct PulseSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(0.88))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

extension Color {
    static let pulseBackground = Color(red: 0.04, green: 0.04, blue: 0.07)
    static let pulseCard = Color(red: 0.10, green: 0.10, blue: 0.13)
    static let pulseAccent = Color(red: 0.79, green: 0.70, blue: 0.98)
    static let pulseMuted = Color(red: 0.50, green: 0.50, blue: 0.58)
    static let pulseTeal = Color(red: 0.22, green: 0.83, blue: 0.79)
    static let pulseOrange = Color(red: 0.95, green: 0.70, blue: 0.44)
    static let pulsePeach = Color(red: 0.98, green: 0.60, blue: 0.53)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BabyStorePreviewFactory.makeStore())
    }
}
