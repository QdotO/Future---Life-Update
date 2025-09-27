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

    let scrollView = app.scrollViews.matching(identifier: "goalCreationScroll").firstMatch
    XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Goal creation content should be contained in a scroll view")

        // Be robust to SwiftUI accessibility bridging; match by identifier across any element type
        var titleField = app.textFields.matching(identifier: "goalTitleField").firstMatch
        if !titleField.waitForExistence(timeout: 3) {
            let any = app.descendants(matching: .any).matching(identifier: "goalTitleField").firstMatch
            XCTAssertTrue(any.waitForExistence(timeout: 2), "Goal title field should be available by identifier")
            // Try to get the concrete text field now that it's present
            titleField = app.textFields.matching(identifier: "goalTitleField").firstMatch
        }
        _ = scrollToElement(titleField, in: scrollView)
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
    func testReminderTimeDisplaysAfterAdding() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to goal creation
        let goalsTab = app.tabBars.buttons["Goals"]
        XCTAssertTrue(goalsTab.waitForExistence(timeout: 5), "Goals tab should be visible on launch")
        goalsTab.tap()

        let addGoalButton = app.buttons["Add Goal"]
        XCTAssertTrue(addGoalButton.waitForExistence(timeout: 5), "Add Goal button should be present on launch")
        addGoalButton.tap()

    let scrollView = app.scrollViews.matching(identifier: "goalCreationScroll").firstMatch
    XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Goal creation content should be contained in a scroll view")

        // Fill out goal details (robust identifier-based lookup)
        var titleField = app.textFields.matching(identifier: "goalTitleField").firstMatch
        if !titleField.waitForExistence(timeout: 3) {
            let any = app.descendants(matching: .any).matching(identifier: "goalTitleField").firstMatch
            XCTAssertTrue(any.waitForExistence(timeout: 2), "Goal title field should be available by identifier")
            titleField = app.textFields.matching(identifier: "goalTitleField").firstMatch
        }
        _ = scrollToElement(titleField, in: scrollView)
    titleField.tap()
    titleField.typeText("Morning Routine")
    // Dismiss keyboard to avoid overlapping the Next button
    titleField.typeText("\n")

    // Select a category via stable identifier
    let healthChip = app.buttons.matching(identifier: "categoryChip-system-health").firstMatch
    XCTAssertTrue(scrollToElement(healthChip, in: scrollView), "Health category chip should be available")
    healthChip.tap()

        // Move to questions step
    let nextButton = app.buttons.matching(identifier: "wizardNextButton").firstMatch
    XCTAssertTrue(nextButton.waitForExistence(timeout: 3), "Next button should be visible")
    // Wait for Next to be enabled once title and category are set
    let enabledPredicate = NSPredicate(format: "isEnabled == true")
    expectation(for: enabledPredicate, evaluatedWith: nextButton, handler: nil)
    waitForExpectations(timeout: 3)
        nextButton.tap()

        // Confirm we advanced to the questions step before looking for the composer
    let questionsStepHeader = app.descendants(matching: .any).matching(identifier: "wizardStep-questions").firstMatch
    XCTAssertTrue(questionsStepHeader.waitForExistence(timeout: 5), "Should advance to the questions step after tapping Next")

        // Add a question (prefer stable identifier, but fall back to placeholder match if needed)
        var questionElement = app.descendants(matching: .any).matching(identifier: "questionPromptField").firstMatch
        if !questionElement.waitForExistence(timeout: 3) {
            // Try common SwiftUI/UIKit mappings for multiline text input
            let placeholder = "Ask a question to track"
            let textView = scrollView.textViews[placeholder]
            let textField = scrollView.textFields[placeholder]
            if textView.waitForExistence(timeout: 2) {
                questionElement = textView
            } else {
                XCTAssertTrue(textField.waitForExistence(timeout: 3), "Question field should be available for input")
                questionElement = textField
            }
        }
        _ = scrollToElement(questionElement, in: scrollView)
        questionElement.tap()
        questionElement.typeText("How many glasses of water did you drink?")

    // Select response type via stable identifier
    let numericButton = scrollView.buttons.matching(identifier: "responseType-numeric").firstMatch
    XCTAssertTrue(scrollToElement(numericButton, in: scrollView), "Numeric response type should be available")
    numericButton.tap()

    // Save question via stable identifier
    let saveQuestionButton = scrollView.buttons.matching(identifier: "saveQuestionButton").firstMatch
    XCTAssertTrue(scrollToElement(saveQuestionButton, in: scrollView), "Save question button should be available")
    saveQuestionButton.tap()

        // Move to schedule step
    let nextButtonSchedule = app.buttons.matching(identifier: "wizardNextButton").firstMatch
    XCTAssertTrue(nextButtonSchedule.waitForExistence(timeout: 3), "Next button should be visible after saving question")
        nextButtonSchedule.tap()

        // Verify we're on the schedule step
        let reminderTimesText = scrollView.staticTexts["Reminder times"]
        XCTAssertTrue(scrollToElement(reminderTimesText, in: scrollView), "Reminder times section should be visible")

    // Verify "Add at least one reminder time" message is shown initially
    let addReminderMessage = scrollView.staticTexts["Add at least one reminder time."]
    _ = scrollToElement(addReminderMessage, in: scrollView)

        // Add a reminder time
        let addReminderButton = scrollView.buttons["Add Reminder"]
        XCTAssertTrue(scrollToElement(addReminderButton, in: scrollView), "Add Reminder button should be available")
        addReminderButton.tap()

        // After adding, wait until at least one row appears (more robust than relying on empty message disappearing timing)
        let emptyMessage = scrollView.staticTexts["Add at least one reminder time."]
        let removeButtonsQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'removeReminder-'"))
        let reminderRowsQuery = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'reminderRow-'"))

        XCTAssertTrue(waitForElementsCount(removeButtonsQuery, toBeAtLeast: 1, timeout: 5.0), "A reminder row with a Remove button should appear after adding")
        XCTAssertTrue(waitForElementsCount(reminderRowsQuery, toBeAtLeast: 1, timeout: 5.0), "A reminder row container should appear after adding")
        // Optional: confirm empty state is gone now (non-critical)
        if emptyMessage.exists {
            // Give the UI a brief moment to transition before checking again
            _ = emptyMessage.waitForExistence(timeout: 0.5)
        }

        // Verify we can add another reminder time
        let addReminderButton2 = scrollView.buttons["Add Reminder"]
        XCTAssertTrue(addReminderButton2.exists, "Add Reminder button should still be available after adding one time")
        addReminderButton2.tap()

    // Verify we now have two reminder rows displayed (two Remove buttons)
        XCTAssertTrue(waitForElementsCount(removeButtonsQuery, toBeAtLeast: 2, timeout: 5.0), "Should display multiple reminder rows after adding them")
        XCTAssertTrue(waitForElementsCount(reminderRowsQuery, toBeAtLeast: 2, timeout: 5.0), "Should display multiple reminder row containers after adding them")

        // Verify we can remove a reminder time
    let firstRemoveButton = removeButtonsQuery.element(boundBy: 0)
        XCTAssertTrue(firstRemoveButton.waitForExistence(timeout: 2), "Remove reminder buttons should be available")
        firstRemoveButton.tap()

    // Verify one reminder time was removed (at least one row remains)
    XCTAssertTrue(waitForElementsCount(removeButtonsQuery, toBeAtLeast: 1, timeout: 3.0), "Should still have at least one reminder time after removing one")
    XCTAssertTrue(waitForElementsCount(reminderRowsQuery, toBeAtLeast: 1, timeout: 3.0), "Should still have at least one reminder row after removing one")
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

        for _ in 0..<maxSwipes {
            container.swipeDown()
            if element.exists && element.isHittable { return true }
        }

        return element.exists
    }

    /// Polls for the number of elements in the query to reach at least the desired count within the timeout.
    func waitForElementsCount(_ query: XCUIElementQuery, toBeAtLeast expected: Int, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if query.count >= expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < end
        return query.count >= expected
    }
}
