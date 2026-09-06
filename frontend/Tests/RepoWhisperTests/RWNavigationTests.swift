import XCTest
@testable import RepoWhisper

final class RWNavigationTests: XCTestCase {
    func testNavigationDestinationsRemainStable() {
        XCTAssertEqual(RWNavigation.allCases.map(\.title), [
            "Ask", "Repositories", "Indexing", "Live Assist", "Settings"
        ])
    }

    func testNavigationSymbolsAreUnique() {
        let symbols = RWNavigation.allCases.map(\.symbol)
        XCTAssertEqual(Set(symbols).count, symbols.count)
    }

    func testNavigationRawValuesRoundTrip() {
        for destination in RWNavigation.allCases {
            XCTAssertEqual(RWNavigation(rawValue: destination.rawValue), destination)
        }
    }
}
