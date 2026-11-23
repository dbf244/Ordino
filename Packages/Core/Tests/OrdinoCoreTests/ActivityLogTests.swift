import Foundation
import OrdinoCore
import Testing

@Suite("ActivityLog")
struct ActivityLogTests {
    let file = URL(fileURLWithPath: "/tmp/a.pdf")

    @Test("Newest entries come first")
    func newestFirst() {
        var log = ActivityLog(capacity: 10)
        log.record(.fileReady(file), at: Date(timeIntervalSince1970: 1))
        log.record(.fileRemoved(file), at: Date(timeIntervalSince1970: 2))
        #expect(log.entries.map(\.activity) == [.fileRemoved(file), .fileReady(file)])
    }

    @Test("The log keeps only the most recent entries")
    func capacity() {
        var log = ActivityLog(capacity: 3)
        for second in 1...5 {
            log.record(.fileReady(URL(fileURLWithPath: "/tmp/\(second)")), at: Date(timeIntervalSince1970: Double(second)))
        }
        #expect(log.entries.count == 3)
        #expect(log.entries.map(\.date.timeIntervalSince1970) == [5, 4, 3])
    }

    @Test("Every entry has a unique identifier")
    func uniqueIDs() {
        var log = ActivityLog(capacity: 10)
        log.record(.fileReady(file), at: .now)
        log.record(.fileReady(file), at: .now)
        #expect(Set(log.entries.map(\.id)).count == 2)
    }
}
