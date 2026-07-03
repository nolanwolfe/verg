import XCTest
@testable import Verg

/// Tests for the pure book grouping logic.
/// NOTE: no test target is wired in the Xcode project yet — these follow the
/// convention of Tests/SessionGatingServiceTests.swift.
final class BookLogicTests: XCTestCase {

    private func makeSession(daysAgo: Int) -> Session {
        Session(
            date: Date().addingTimeInterval(-Double(daysAgo) * 86400),
            duration: 900,
            imagePath: "x.jpg",
            createdAt: Date().addingTimeInterval(-Double(daysAgo) * 86400)
        )
    }

    func testAllSessionsCurrentWithNoBooks() {
        let sessions = [makeSession(daysAgo: 1), makeSession(daysAgo: 2)]
        XCTAssertEqual(Book.currentSessions(from: sessions, books: []).count, 2)
    }

    func testMakeBookArchivesGivenSessions() {
        let old = makeSession(daysAgo: 10)
        let recent = makeSession(daysAgo: 1)
        let book = Book.make(title: "Journal 1", archiving: [old, recent], coverStyle: 0)
        XCTAssertEqual(book?.pageCount, 2)
        XCTAssertEqual(book?.startDate, old.date)
        XCTAssertEqual(book?.endDate, recent.date)
    }

    func testCurrentSessionsExcludesBookedIDs() {
        let archived = makeSession(daysAgo: 10)
        let current = makeSession(daysAgo: 1)
        let book = Book.make(title: "Journal 1", archiving: [archived], coverStyle: 0)!
        let remaining = Book.currentSessions(from: [current, archived], books: [book])
        XCTAssertEqual(remaining.map(\.id), [current.id])
    }

    func testEmptyArchiveRefused() {
        XCTAssertNil(Book.make(title: "Empty", archiving: [], coverStyle: 0))
    }

    func testResolveToleratesDeletedSessions() {
        let kept = makeSession(daysAgo: 1)
        let deleted = makeSession(daysAgo: 2)
        let book = Book.make(title: "Journal 1", archiving: [kept, deleted], coverStyle: 0)!
        XCTAssertEqual(book.resolveSessions(from: [kept]).map(\.id), [kept.id])
    }
}
