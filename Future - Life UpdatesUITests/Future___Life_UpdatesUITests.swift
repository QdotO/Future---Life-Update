//___FILEHEADER___

import XCTest

final class FutureLifeUpdatesUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCategoryOverflowReveal() throws {
        let app = XCUIApplication()
        app.launch()

    let goalsTab = app.tabBars.buttons["Goals"]
    XCTAssertTrue(goalsTab.waitForExistence(timeout: 5), "Goals tab should be visible on launch")
    goalsTab.tap()

    let addGoalButton = app.buttons["Add Goal"]
    XCTAssertTrue(addGoalButton.waitForExistence(timeout: 5), "Add Goal button should be present on launch")
        addGoalButton.tap()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 2), "Goal creation content should be contained in a scroll view")

        let moreCategoriesButton = app.buttons["More categories"]
        XCTAssertTrue(scrollToElement(moreCategoriesButton, in: scrollView), "More categories control should appear in creation flow")
        moreCategoriesButton.tap()

        let financeChip = app.buttons["Finance"]
        XCTAssertTrue(scrollToElement(financeChip, in: scrollView), "Finance chip should be visible after expanding overflow")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

private extension FutureLifeUpdatesUITests {
    @discardableResult
    func scrollToElement(_ element: XCUIElement, in container: XCUIElement, maxSwipes: Int = 6) -> Bool {
        guard container.exists else { return element.exists }

        if element.exists && element.isHittable { return true }

        for _ in 0..<maxSwipes {
            container.swipeUp()
            if element.exists && element.isHittable { return true }
        }

        return element.exists
    }
}
