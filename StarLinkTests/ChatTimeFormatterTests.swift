#if DEBUG
import XCTest
@testable import StarLink

final class ChatTimeFormatterTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    func testTodayShowsTime() {
        let now = date(2026, 11, 15, 12, 0)
        XCTAssertEqual(ChatTimeFormatter.string(for: date(2026, 11, 15, 9, 41), now: now), "09:41")
    }

    func testYesterdayLabel() {
        let now = date(2026, 11, 15, 12, 0)
        XCTAssertEqual(ChatTimeFormatter.string(for: date(2026, 11, 14, 22, 5), now: now), "昨天")
    }

    func testOlderShowsShortDate() {
        let now = date(2026, 11, 15, 12, 0)
        XCTAssertEqual(ChatTimeFormatter.string(for: date(2026, 11, 2, 10, 30), now: now), "11/2")
    }
}
#endif
