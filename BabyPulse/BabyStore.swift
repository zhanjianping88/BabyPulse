//
//  BabyStore.swift
//  BabyPulse
//
//  Created by Codex on 2026/3/26.
//

import Combine
import Foundation

enum AppTab: Hashable {
    case home
    case timeline
    case stats
}

enum QuickLogDestination: Identifiable {
    case sleep
    case feed
    case diaper

    var id: Self { self }
}

enum FeedType: String, CaseIterable, Identifiable, Codable {
    case breast
    case bottle
    case formula

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breast: "Breast"
        case .bottle: "Bottle"
        case .formula: "Formula"
        }
    }

    var icon: String {
        switch self {
        case .breast: "figure.seated.side.air.upper"
        case .bottle: "waterbottle"
        case .formula: "drop.degreesign"
        }
    }
}

enum DiaperType: String, CaseIterable, Identifiable, Codable {
    case wet
    case dirty
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wet: "Wet"
        case .dirty: "Dirty"
        case .mixed: "Mixed"
        }
    }

    var icon: String {
        switch self {
        case .wet: "drop.fill"
        case .dirty: "sparkles.rectangle.stack.fill"
        case .mixed: "plus.square.fill"
        }
    }
}

struct SleepSession: Identifiable, Equatable, Codable {
    let id: UUID
    let start: Date
    let end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

struct FeedLog: Identifiable, Equatable, Codable {
    let id: UUID
    let date: Date
    let type: FeedType
    let amountML: Int

    init(id: UUID = UUID(), date: Date, type: FeedType, amountML: Int) {
        self.id = id
        self.date = date
        self.type = type
        self.amountML = amountML
    }
}

struct DiaperLog: Identifiable, Equatable, Codable {
    let id: UUID
    let date: Date
    let type: DiaperType

    init(id: UUID = UUID(), date: Date, type: DiaperType) {
        self.id = id
        self.date = date
        self.type = type
    }
}

struct TimelineItem: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let icon: String
    let kind: TimelineKind
}

enum TimelineKind: Equatable {
    case sleep
    case feed
    case diaper(DiaperType)
}

enum TimelineEditorDestination: Identifiable {
    case sleep(UUID)
    case feed(UUID)
    case diaper(UUID)

    var id: String {
        switch self {
        case let .sleep(id): "sleep-\(id.uuidString)"
        case let .feed(id): "feed-\(id.uuidString)"
        case let .diaper(id): "diaper-\(id.uuidString)"
        }
    }
}

struct SharedTrackerImportSummary: Equatable {
    let sleepSessions: Int
    let feedLogs: Int
    let diaperLogs: Int
    let hasActiveSleep: Bool
}

private struct BabyPulseSnapshot: Codable {
    var sleepSessions: [SleepSession]
    var feedLogs: [FeedLog]
    var diaperLogs: [DiaperLog]
    var activeSleepStart: Date?
}

private struct SharedTrackerPayload: Codable {
    let version: Int
    let exportedAt: Date
    let snapshot: BabyPulseSnapshot
}

enum SharedTrackerCodeError: LocalizedError {
    case emptyCode
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .emptyCode:
            "Paste a shared tracker code first."
        case .invalidCode:
            "That shared tracker code is not valid."
        }
    }
}

@MainActor
final class BabyStore: ObservableObject {
    @Published private(set) var sleepSessions: [SleepSession]
    @Published private(set) var feedLogs: [FeedLog]
    @Published private(set) var diaperLogs: [DiaperLog]
    @Published var activeSleepStart: Date? {
        didSet {
            persist()
        }
    }

    private let storageURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let sharedEncoder = JSONEncoder()
    private let sharedDecoder = JSONDecoder()

    init(
        sleepSessions: [SleepSession] = [],
        feedLogs: [FeedLog] = [],
        diaperLogs: [DiaperLog] = [],
        activeSleepStart: Date? = nil,
        loadPersistedData: Bool = true
    ) {
        self.sleepSessions = sleepSessions
        self.feedLogs = feedLogs
        self.diaperLogs = diaperLogs
        self.activeSleepStart = activeSleepStart
        self.storageURL = Self.makeStorageURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = Self.flexibleDateDecodingStrategy
        sharedEncoder.dateEncodingStrategy = .iso8601
        sharedDecoder.dateDecodingStrategy = Self.flexibleDateDecodingStrategy

        if loadPersistedData {
            load()
        }
    }

    func startSleep(at date: Date = .now) {
        guard activeSleepStart == nil else { return }
        activeSleepStart = date
    }

    func endSleep(at date: Date = .now) {
        guard let start = activeSleepStart, date >= start else { return }
        sleepSessions.insert(SleepSession(start: start, end: date), at: 0)
        activeSleepStart = nil
        persist()
    }

    func addFeed(type: FeedType, amountML: Int, at date: Date = .now) {
        guard amountML > 0 else { return }
        feedLogs.insert(FeedLog(date: date, type: type, amountML: amountML), at: 0)
        persist()
    }

    func addDiaper(type: DiaperType, at date: Date = .now) {
        diaperLogs.insert(DiaperLog(date: date, type: type), at: 0)
        persist()
    }

    func updateSleep(id: UUID, start: Date, end: Date) {
        guard start <= end, let index = sleepSessions.firstIndex(where: { $0.id == id }) else { return }
        sleepSessions[index] = SleepSession(id: id, start: start, end: end)
        sleepSessions.sort { $0.end > $1.end }
        persist()
    }

    func updateFeed(id: UUID, type: FeedType, amountML: Int, date: Date) {
        guard amountML > 0, let index = feedLogs.firstIndex(where: { $0.id == id }) else { return }
        feedLogs[index] = FeedLog(id: id, date: date, type: type, amountML: amountML)
        feedLogs.sort { $0.date > $1.date }
        persist()
    }

    func updateDiaper(id: UUID, type: DiaperType, date: Date) {
        guard let index = diaperLogs.firstIndex(where: { $0.id == id }) else { return }
        diaperLogs[index] = DiaperLog(id: id, date: date, type: type)
        diaperLogs.sort { $0.date > $1.date }
        persist()
    }

    func deleteTimelineItem(_ item: TimelineItem) {
        switch item.kind {
        case .sleep:
            sleepSessions.removeAll { $0.id == item.id }
        case .feed:
            feedLogs.removeAll { $0.id == item.id }
        case .diaper:
            diaperLogs.removeAll { $0.id == item.id }
        }
        persist()
    }

    func todaySleepDuration(referenceDate: Date = .now, calendar: Calendar = .current) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? referenceDate

        let completed = sleepSessions.reduce(into: 0.0) { partial, session in
            partial += overlapDuration(start: session.start, end: session.end, rangeStart: dayStart, rangeEnd: tomorrow)
        }

        let active = activeSleepStart.map {
            overlapDuration(start: $0, end: referenceDate, rangeStart: dayStart, rangeEnd: tomorrow)
        } ?? 0

        return completed + active
    }

    func todayFeedTotal(referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        feedLogs
            .filter { calendar.isDate($0.date, inSameDayAs: referenceDate) }
            .reduce(0) { $0 + $1.amountML }
    }

    func todayDiaperCount(for type: DiaperType? = nil, referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        diaperLogs.filter { log in
            guard calendar.isDate(log.date, inSameDayAs: referenceDate) else { return false }
            guard let type else { return true }
            return log.type == type
        }.count
    }

    func timeline(limit: Int = 20) -> [TimelineItem] {
        let sleepItems = sleepSessions.map {
            TimelineItem(
                id: $0.id,
                date: $0.end,
                title: "Nap",
                detail: $0.duration.clockText,
                icon: "moon.fill",
                kind: .sleep
            )
        }

        let activeItem = activeSleepStart.map {
            TimelineItem(
                id: UUID(),
                date: $0,
                title: "Sleeping now",
                detail: "Started \(RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: .now))",
                icon: "moon.stars.fill",
                kind: .sleep
            )
        }

        let feedItems = feedLogs.map {
            TimelineItem(
                id: $0.id,
                date: $0.date,
                title: $0.type.title,
                detail: "\($0.amountML) mL",
                icon: "drop.circle.fill",
                kind: .feed
            )
        }

        let diaperItems = diaperLogs.map {
            TimelineItem(
                id: $0.id,
                date: $0.date,
                title: $0.type.title,
                detail: "Routine check",
                icon: $0.type.icon,
                kind: .diaper($0.type)
            )
        }

        return ([activeItem].compactMap { $0 } + sleepItems + feedItems + diaperItems)
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    var lastFeed: FeedLog? { feedLogs.first }
    var lastDiaper: DiaperLog? { diaperLogs.first }
    var latestSleep: SleepSession? { sleepSessions.first }

    func sleepSession(id: UUID) -> SleepSession? {
        sleepSessions.first { $0.id == id }
    }

    func feedLog(id: UUID) -> FeedLog? {
        feedLogs.first { $0.id == id }
    }

    func diaperLog(id: UUID) -> DiaperLog? {
        diaperLogs.first { $0.id == id }
    }

    func sleepSessionsCount(referenceDate: Date = .now, inLastHours hours: Int, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .hour, value: -hours, to: referenceDate) ?? referenceDate
        return sleepSessions.filter { $0.end >= start }.count
    }

    func feedCount(referenceDate: Date = .now, inLastHours hours: Int, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .hour, value: -hours, to: referenceDate) ?? referenceDate
        return feedLogs.filter { $0.date >= start }.count
    }

    func diaperCount(referenceDate: Date = .now, inLastHours hours: Int, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .hour, value: -hours, to: referenceDate) ?? referenceDate
        return diaperLogs.filter { $0.date >= start }.count
    }

    func averageFeedAmount(referenceDate: Date = .now, inLastHours hours: Int, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .hour, value: -hours, to: referenceDate) ?? referenceDate
        let recentFeeds = feedLogs.filter { $0.date >= start }
        guard recentFeeds.isEmpty == false else { return 0 }
        return recentFeeds.reduce(0) { $0 + $1.amountML } / recentFeeds.count
    }

    func sleepDuration(referenceDate: Date = .now, inLastDays days: Int, calendar: Calendar = .current) -> TimeInterval {
        let start = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        return sleepSessions.reduce(into: 0.0) { partial, session in
            partial += overlapDuration(start: session.start, end: session.end, rangeStart: start, rangeEnd: referenceDate)
        }
    }

    func feedVolume(referenceDate: Date = .now, inLastDays days: Int, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        return feedLogs.filter { $0.date >= start }.reduce(0) { $0 + $1.amountML }
    }

    func exportSharedTrackerCode() throws -> String {
        let payload = SharedTrackerPayload(
            version: 1,
            exportedAt: .now,
            snapshot: snapshot()
        )
        let data = try sharedEncoder.encode(payload)
        return data.base64EncodedString()
    }

    func previewSharedTrackerImport(_ code: String) throws -> SharedTrackerImportSummary {
        let payload = try decodeSharedTrackerPayload(from: code)
        return summary(for: payload.snapshot)
    }

    @discardableResult
    func importSharedTrackerCode(_ code: String) throws -> SharedTrackerImportSummary {
        let payload = try decodeSharedTrackerPayload(from: code)

        apply(snapshot: payload.snapshot)
        persist()

        return summary(for: payload.snapshot)
    }

    func clearAllData() {
        apply(
            snapshot: BabyPulseSnapshot(
                sleepSessions: [],
                feedLogs: [],
                diaperLogs: [],
                activeSleepStart: nil
            )
        )
        persist()
    }

    private func load() {
        guard let storageURL, let data = try? Data(contentsOf: storageURL) else { return }

        do {
            let snapshot = try decoder.decode(BabyPulseSnapshot.self, from: data)
            apply(snapshot: snapshot)
        } catch {
            assertionFailure("Failed to decode BabyPulse data: \(error)")
        }
    }

    private func persist() {
        guard let storageURL else { return }

        let snapshot = BabyPulseSnapshot(
            sleepSessions: sleepSessions,
            feedLogs: feedLogs,
            diaperLogs: diaperLogs,
            activeSleepStart: activeSleepStart
        )

        do {
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: storageURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist BabyPulse data: \(error)")
        }
    }

    private func snapshot() -> BabyPulseSnapshot {
        BabyPulseSnapshot(
            sleepSessions: sleepSessions,
            feedLogs: feedLogs,
            diaperLogs: diaperLogs,
            activeSleepStart: activeSleepStart
        )
    }

    private func summary(for snapshot: BabyPulseSnapshot) -> SharedTrackerImportSummary {
        SharedTrackerImportSummary(
            sleepSessions: snapshot.sleepSessions.count,
            feedLogs: snapshot.feedLogs.count,
            diaperLogs: snapshot.diaperLogs.count,
            hasActiveSleep: snapshot.activeSleepStart != nil
        )
    }

    private func apply(snapshot: BabyPulseSnapshot) {
        sleepSessions = snapshot.sleepSessions.sorted { $0.end > $1.end }
        feedLogs = snapshot.feedLogs.sorted { $0.date > $1.date }
        diaperLogs = snapshot.diaperLogs.sorted { $0.date > $1.date }
        activeSleepStart = snapshot.activeSleepStart
    }

    private func decodeSharedTrackerPayload(from code: String) throws -> SharedTrackerPayload {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.isEmpty == false else {
            throw SharedTrackerCodeError.emptyCode
        }

        if let data = Data(base64Encoded: trimmedCode) {
            do {
                return try sharedDecoder.decode(SharedTrackerPayload.self, from: data)
            } catch {
                throw SharedTrackerCodeError.invalidCode
            }
        }

        if let data = trimmedCode.data(using: .utf8) {
            do {
                return try sharedDecoder.decode(SharedTrackerPayload.self, from: data)
            } catch {
                throw SharedTrackerCodeError.invalidCode
            }
        }

        throw SharedTrackerCodeError.invalidCode
    }

    private static var flexibleDateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()

            if let stringValue = try? container.decode(String.self),
               let date = formatter.date(from: stringValue) {
                return date
            }

            if let referenceSeconds = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: referenceSeconds)
            }

            if let referenceSeconds = try? container.decode(Int.self) {
                return Date(timeIntervalSinceReferenceDate: TimeInterval(referenceSeconds))
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO8601 string or legacy Apple reference-date number."
            )
        }
    }

    private func overlapDuration(start: Date, end: Date, rangeStart: Date, rangeEnd: Date) -> TimeInterval {
        let actualStart = max(start, rangeStart)
        let actualEnd = min(end, rangeEnd)
        return max(0, actualEnd.timeIntervalSince(actualStart))
    }

    private static func makeStorageURL() -> URL? {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return baseURL?.appendingPathComponent("BabyPulse", isDirectory: true)
            .appendingPathComponent("baby-pulse-data.json")
    }
}

enum BabyStorePreviewFactory {
    @MainActor
    static func makeStore() -> BabyStore {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        return BabyStore(
            sleepSessions: [
                SleepSession(start: calendar.date(byAdding: .minute, value: -135, to: now) ?? now, end: calendar.date(byAdding: .minute, value: -15, to: now) ?? now),
                SleepSession(start: calendar.date(byAdding: .hour, value: 1, to: today) ?? today, end: calendar.date(byAdding: .hour, value: 4, to: today) ?? today),
                SleepSession(start: calendar.date(byAdding: .hour, value: 5, to: today) ?? today, end: calendar.date(byAdding: .hour, value: 10, to: today) ?? today)
            ],
            feedLogs: [
                FeedLog(date: calendar.date(byAdding: .minute, value: -170, to: now) ?? now, type: .breast, amountML: 90),
                FeedLog(date: calendar.date(byAdding: .hour, value: -6, to: now) ?? now, type: .bottle, amountML: 120)
            ],
            diaperLogs: [
                DiaperLog(date: calendar.date(byAdding: .minute, value: -80, to: now) ?? now, type: .wet),
                DiaperLog(date: calendar.date(byAdding: .hour, value: -5, to: now) ?? now, type: .dirty),
                DiaperLog(date: calendar.date(byAdding: .hour, value: -9, to: now) ?? now, type: .mixed)
            ],
            loadPersistedData: false
        )
    }
}

extension TimeInterval {
    var clockText: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours == 0 {
            return String(format: "%02d:%02d", minutes, totalSeconds % 60)
        }

        return "\(hours)h \(minutes)m"
    }

    var dashboardText: String {
        let totalMinutes = Int(self / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}
