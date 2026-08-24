import XCTest
@testable import RepoWhisper

final class FloatingPopupLifecycleTests: XCTestCase {
    func testAutoHideRetainsWindowForReopen() {
        var lifecycle = FloatingPopupLifecycle()
        lifecycle.didCreateWindow()

        lifecycle.didHideWindow()

        XCTAssertTrue(lifecycle.hasReusableWindow)
        XCTAssertFalse(lifecycle.isVisible)
        XCTAssertEqual(lifecycle.showCommand(), .reveal)
    }

    func testToggleRevealsRetainedHiddenWindow() {
        var lifecycle = FloatingPopupLifecycle()
        lifecycle.didCreateWindow()
        lifecycle.didHideWindow()

        XCTAssertEqual(lifecycle.toggleCommand(), .reveal)

        lifecycle.didRevealWindow()
        XCTAssertTrue(lifecycle.isVisible)
        XCTAssertEqual(lifecycle.toggleCommand(), .conceal)
    }

    func testClosedWindowCannotBeRevealed() {
        var lifecycle = FloatingPopupLifecycle()
        lifecycle.didCreateWindow()

        lifecycle.didCloseWindow()

        XCTAssertFalse(lifecycle.hasReusableWindow)
        XCTAssertFalse(lifecycle.isVisible)
        XCTAssertEqual(lifecycle.showCommand(), .none)
    }
}
