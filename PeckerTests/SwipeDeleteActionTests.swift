import XCTest
@testable import Pecker

final class SwipeDeleteActionTests: XCTestCase {
    func testOpenedActionCanBeDraggedFullyClosed() {
        var state = SwipeDeleteState(actionWidth: 82)
        state.isOpen = true

        state.updateDrag(translationWidth: 82, isHorizontal: true)

        XCTAssertEqual(state.currentOffset, 0)
    }

    func testRightSwipeFromOpenedActionClosesOnEnd() {
        var state = SwipeDeleteState(actionWidth: 82)
        state.isOpen = true

        state.updateDrag(translationWidth: 70, isHorizontal: true)
        state.endDrag(predictedEndTranslationWidth: 70)

        XCTAssertFalse(state.isOpen)
        XCTAssertEqual(state.currentOffset, 0)
    }

    func testLeftSwipeFromClosedActionOpensOnEnd() {
        var state = SwipeDeleteState(actionWidth: 82)

        state.updateDrag(translationWidth: -70, isHorizontal: true)
        state.endDrag(predictedEndTranslationWidth: -70)

        XCTAssertTrue(state.isOpen)
        XCTAssertEqual(state.currentOffset, -82)
    }

    func testHorizontalDragSuppressesNextTap() {
        var state = SwipeDeleteState(actionWidth: 82)

        state.updateDrag(translationWidth: -24, isHorizontal: true)

        XCTAssertTrue(state.consumeTapSuppression())
        XCTAssertFalse(state.consumeTapSuppression())
    }

    func testDeleteActionReceivesHitTestingOnlyWhenOpen() {
        var state = SwipeDeleteState(actionWidth: 82)

        XCTAssertFalse(state.deleteActionReceivesHitTesting)

        state.updateDrag(translationWidth: -70, isHorizontal: true)
        state.endDrag(predictedEndTranslationWidth: -70)

        XCTAssertTrue(state.deleteActionReceivesHitTesting)

        state.close()

        XCTAssertFalse(state.deleteActionReceivesHitTesting)
    }
}
