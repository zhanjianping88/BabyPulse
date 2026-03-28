//
//  BabyPulseTests.swift
//  BabyPulseTests
//
//  Created by 建平 on 2026/3/26.
//

import Foundation
import Testing
@testable import BabyPulse

struct BabyPulseTests {

    @MainActor
    @Test func todaySleepIncludesCompletedAndActiveSessions() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_710_000_000)
        let session = SleepSession(
            id: UUID(),
            start: day.addingTimeInterval(60 * 60),
            end: day.addingTimeInterval(3 * 60 * 60)
        )
        let store = BabyStore(
            sleepSessions: [session],
            activeSleepStart: day.addingTimeInterval(5 * 60 * 60)
        )

        let duration = store.todaySleepDuration(
            referenceDate: day.addingTimeInterval(6 * 60 * 60),
            calendar: calendar
        )

        #expect(duration == 10_800)
    }

    @MainActor
    @Test func timelineIsSortedNewestFirst() async throws {
        let base = Date(timeIntervalSince1970: 1_710_000_000)
        let store = BabyStore(
            sleepSessions: [
                SleepSession(id: UUID(), start: base, end: base.addingTimeInterval(600))
            ],
            feedLogs: [
                FeedLog(id: UUID(), date: base.addingTimeInterval(1_800), type: .bottle, amountML: 120)
            ],
            diaperLogs: [
                DiaperLog(id: UUID(), date: base.addingTimeInterval(900), type: .wet)
            ]
        )

        let timeline = store.timeline(limit: 3)

        #expect(timeline.count == 3)
        #expect(timeline.map { $0.title } == ["Bottle", "Wet", "Nap"])
    }

    @MainActor
    @Test func sharedTrackerCodeRoundTripRestoresData() async throws {
        let base = Date(timeIntervalSince1970: 1_710_000_000)
        let source = BabyStore(
            sleepSessions: [
                SleepSession(id: UUID(), start: base, end: base.addingTimeInterval(1_200))
            ],
            feedLogs: [
                FeedLog(id: UUID(), date: base.addingTimeInterval(600), type: .formula, amountML: 150)
            ],
            diaperLogs: [
                DiaperLog(id: UUID(), date: base.addingTimeInterval(300), type: .mixed)
            ],
            activeSleepStart: base.addingTimeInterval(1_800),
            loadPersistedData: false
        )
        let target = BabyStore(loadPersistedData: false)

        let code = try source.exportSharedTrackerCode()
        let summary = try target.importSharedTrackerCode(code)

        #expect(summary == SharedTrackerImportSummary(sleepSessions: 1, feedLogs: 1, diaperLogs: 1, hasActiveSleep: true))
        #expect(target.sleepSessions.count == 1)
        #expect(target.feedLogs.count == 1)
        #expect(target.diaperLogs.count == 1)
        #expect(target.activeSleepStart == base.addingTimeInterval(1_800))
    }

    @MainActor
    @Test func sharedTrackerImportAcceptsJsonPayload() async throws {
        let source = BabyStore(
            feedLogs: [
                FeedLog(id: UUID(), date: Date(timeIntervalSince1970: 1_710_000_123), type: .bottle, amountML: 120)
            ],
            loadPersistedData: false
        )
        let target = BabyStore(loadPersistedData: false)

        let code = try source.exportSharedTrackerCode()
        let jsonData = try #require(Data(base64Encoded: code))
        let jsonString = try #require(String(data: jsonData, encoding: .utf8))

        let summary = try target.importSharedTrackerCode(jsonString)

        #expect(summary.feedLogs == 1)
        #expect(target.feedLogs.first?.amountML == 120)
    }

}
