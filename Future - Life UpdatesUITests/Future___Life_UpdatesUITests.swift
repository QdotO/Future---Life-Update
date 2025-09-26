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
    func testQuestionComposerHidesNavigationWhileTyping() throws {
        let app = XCUIApplication()
        app.launch()

        let goalsTab = app.tabBars.buttons["Goals"]
        XCTAssertTrue(goalsTab.waitForExistence(timeout: 5), "Goals tab should be visible on launch")
        goalsTab.tap()

        let addGoalButton = app.buttons["Add Goal"]
        XCTAssertTrue(addGoalButton.waitForExistence(timeout: 5), "Add Goal button should be present on launch")
        addGoalButton.tap()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Goal creation content should be contained in a scroll view")

        let titleField = scrollView.textFields["Goal title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2), "Goal title field should be available")
        titleField.tap()
        titleField.typeText("Sleep quality")

        let categoryLabels = ["Health", "Fitness", "Productivity", "Habits", "Mood", "Learning"]
        var didSelectCategory = false
        for label in categoryLabels {
            let chip = scrollView.buttons[label]
            if chip.waitForExistence(timeout: 0.5) {
                _ = scrollToElement(chip, in: scrollView)
                if chip.isHittable {
                    chip.tap()
                    didSelectCategory = true
                    break
                }
            }
        }
        XCTAssertTrue(didSelectCategory, "Should be able to select a primary category")

        var nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 2), "Next button should be visible before proceeding")
        nextButton.tap()

        nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 2), "Next button should appear on the questions step before typing")

        let questionTextView = scrollView.textViews["Ask a question to track"]
        let questionField: XCUIElement
        if questionTextView.waitForExistence(timeout: 2) {
            questionField = questionTextView
        } else {
            let fallbackField = scrollView.textFields["Ask a question to track"]
            XCTAssertTrue(fallbackField.waitForExistence(timeout: 2), "Question field should be available for input")
            questionField = fallbackField
        }

        questionField.tap()
        questionField.typeText("How many hours did you sleep?")

        let disappearanceExpectation = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: nextButton, handler: nil)
        wait(for: [disappearanceExpectation], timeout: 2.0)
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
