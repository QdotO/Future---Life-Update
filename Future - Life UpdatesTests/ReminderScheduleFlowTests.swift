import Testing
import SwiftData
import SwiftUI
@testable import Future___Life_Updates

@MainActor
struct ReminderScheduleFlowTests {
    
    /// Create an in-memory SwiftData container for isolated testing
    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrackingGoal.self, configurations: config)
        return container
    }
    
    @Test("Complete reminder schedule flow creates goal with correct times")
    func completeReminderScheduleFlowCreatesGoalWithCorrectTimes() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        // Initialize view model
        let viewModel = GoalCreationViewModel(modelContext: context)
        
        // Set up basic goal details
        viewModel.title = "Test Goal"
        viewModel.selectCategory(.system(.health))
        
        // Add a question
        _ = viewModel.addManualQuestion(
            text: "How are you feeling?", 
            responseType: .scale,
            validationRules: ValidationRules(minimumValue: 1, maximumValue: 10)
        )
        
        #expect(viewModel.hasDraftQuestions)
        #expect(viewModel.draftQuestions.count == 1)
        
        // Set up schedule
        let reminderTime1 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let reminderTime2 = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
        
        // Test adding first reminder time
        let didAdd1 = viewModel.addScheduleTime(from: reminderTime1)
        #expect(didAdd1)
        #expect(viewModel.scheduleDraft.times.count == 1)
        #expect(viewModel.scheduleDraft.times.first?.hour == 9)
        #expect(viewModel.scheduleDraft.times.first?.minute == 0)
        
        // Test adding second reminder time
        let didAdd2 = viewModel.addScheduleTime(from: reminderTime2)
        #expect(didAdd2)
        #expect(viewModel.scheduleDraft.times.count == 2)
        
        // Verify times are sorted correctly
        let sortedTimes = viewModel.scheduleDraft.times.sorted { $0.totalMinutes < $1.totalMinutes }
        #expect(sortedTimes[0].hour == 9)
        #expect(sortedTimes[0].minute == 0)
        #expect(sortedTimes[1].hour == 18)
        #expect(sortedTimes[1].minute == 30)
        
        // Create the goal
        let goal = try viewModel.createGoal()
        
        // Verify the goal was created with correct schedule times
        #expect(goal.schedule.times.count == 2)
        #expect(goal.schedule.times.contains { $0.hour == 9 && $0.minute == 0 })
        #expect(goal.schedule.times.contains { $0.hour == 18 && $0.minute == 30 })
        
        // Verify the goal is persisted correctly
        let fetchDescriptor = FetchDescriptor<TrackingGoal>()
        let fetchedGoals = try context.fetch(fetchDescriptor)
        #expect(fetchedGoals.count == 1)
        
        let fetchedGoal = fetchedGoals[0]
        #expect(fetchedGoal.id == goal.id)
        #expect(fetchedGoal.schedule.times.count == 2)
        #expect(fetchedGoal.schedule.times.contains { $0.hour == 9 && $0.minute == 0 })
        #expect(fetchedGoal.schedule.times.contains { $0.hour == 18 && $0.minute == 30 })
    }
    
    @Test("Adding reminder times with conflicts is prevented")
    func addingReminderTimesWithConflictsIsPrevented() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let viewModel = GoalCreationViewModel(modelContext: context)
        
        // Add first reminder time
        let reminderTime1 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let didAdd1 = viewModel.addScheduleTime(from: reminderTime1)
        #expect(didAdd1)
        #expect(viewModel.scheduleDraft.times.count == 1)
        
        // Try to add a conflicting time (within 5 minutes)
        let conflictingTime = Calendar.current.date(bySettingHour: 9, minute: 3, second: 0, of: Date()) ?? Date()
        let didAdd2 = viewModel.addScheduleTime(from: conflictingTime)
        #expect(!didAdd2)
        #expect(viewModel.scheduleDraft.times.count == 1) // Should still be 1
        
        // Try to add a non-conflicting time (outside 5 minute window)
        let validTime = Calendar.current.date(bySettingHour: 9, minute: 10, second: 0, of: Date()) ?? Date()
        let didAdd3 = viewModel.addScheduleTime(from: validTime)
        #expect(didAdd3)
        #expect(viewModel.scheduleDraft.times.count == 2)
    }
    
    @Test("Reminder times can be removed from schedule")
    func reminderTimesCanBeRemovedFromSchedule() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let viewModel = GoalCreationViewModel(modelContext: context)
        
        // Add two reminder times
        let time1 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let time2 = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        
        let didAdd1 = viewModel.addScheduleTime(from: time1)
        let didAdd2 = viewModel.addScheduleTime(from: time2)
        
        #expect(didAdd1)
        #expect(didAdd2)
        #expect(viewModel.scheduleDraft.times.count == 2)
        
        // Find and remove the first time
        let scheduleTime1 = ScheduleTime(hour: 9, minute: 0)
        viewModel.removeScheduleTime(scheduleTime1)
        
        #expect(viewModel.scheduleDraft.times.count == 1)
        #expect(!viewModel.scheduleDraft.times.contains { $0.hour == 9 && $0.minute == 0 })
        #expect(viewModel.scheduleDraft.times.contains { $0.hour == 18 && $0.minute == 0 })
    }
    
    @Test("Schedule times are formatted correctly for display")
    func scheduleTimesAreFormattedCorrectlyForDisplay() throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        
        let morningTime = ScheduleTime(hour: 9, minute: 0)
        let eveningTime = ScheduleTime(hour: 18, minute: 30)
        let lateTime = ScheduleTime(hour: 23, minute: 45)
        
        let morningFormatted = morningTime.formattedTime(in: timezone)
        let eveningFormatted = eveningTime.formattedTime(in: timezone)
        let lateFormatted = lateTime.formattedTime(in: timezone)
        
        // These should be properly formatted times
        #expect(morningFormatted.contains("9:00"))
        #expect(eveningFormatted.contains("6:30"))
        #expect(lateFormatted.contains("11:45"))
    }
    
    @Test("Suggested reminder times avoid conflicts with existing goals")
    func suggestedReminderTimesAvoidConflictsWithExistingGoals() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        // Create an existing goal with a reminder at 9:00 AM
        let existingSchedule = Schedule(
            startDate: Date(),
            frequency: .daily,
            times: [ScheduleTime(hour: 9, minute: 0)],
            timezoneIdentifier: TimeZone.current.identifier
        )
        let existingGoal = TrackingGoal(
            title: "Existing Goal",
            description: "",
            category: .health,
            schedule: existingSchedule
        )
        existingSchedule.goal = existingGoal
        context.insert(existingGoal)
        try context.save()
        
        // Create new view model
        let viewModel = GoalCreationViewModel(modelContext: context)
        
        // Request a suggested time starting at 9:00 AM (which should conflict)
        let conflictingBase = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let suggestedTime = viewModel.suggestedReminderDate(startingAt: conflictingBase)
        
        // Verify the suggested time is not 9:00 AM (should avoid conflict)
        let components = Calendar.current.dateComponents([.hour, .minute], from: suggestedTime)
        let suggestedScheduleTime = ScheduleTime(components: components)
        
        #expect(!suggestedScheduleTime.isWithin(window: 5 * 60, of: ScheduleTime(hour: 9, minute: 0)))
    }
    
    @Test("Weekly schedule with selected weekdays is preserved")
    func weeklyScheduleWithSelectedWeekdaysIsPreserved() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let viewModel = GoalCreationViewModel(modelContext: context)
        
        // Set up goal details
        viewModel.title = "Weekly Goal"
        viewModel.selectCategory(.system(.productivity))
        viewModel.addManualQuestion(text: "Did you complete your tasks?", responseType: .boolean)
        
        // Set weekly frequency
        viewModel.setFrequency(.weekly)
        #expect(viewModel.scheduleDraft.frequency == .weekly)
        
        // Select specific weekdays
        let selectedWeekdays: Set<Weekday> = [.monday, .wednesday, .friday]
        viewModel.updateSelectedWeekdays(selectedWeekdays)
        #expect(viewModel.scheduleDraft.selectedWeekdays == selectedWeekdays)
        
        // Add reminder time
        let reminderTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
        let didAdd = viewModel.addScheduleTime(from: reminderTime)
        #expect(didAdd)
        
        // Create goal and verify schedule
        let goal = try viewModel.createGoal()
        #expect(goal.schedule.frequency == .weekly)
        #expect(Set(goal.schedule.selectedWeekdays) == selectedWeekdays)
        #expect(goal.schedule.times.count == 1)
        #expect(goal.schedule.times.first?.hour == 10)
    }

    @Test("Flow view model persists goal draft with schedule and templates")
    func flowViewModelPersistsGoalDraftWithScheduleAndTemplates() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let legacy = GoalCreationViewModel(modelContext: context)
        let flow = GoalCreationFlowViewModel(legacyViewModel: legacy)

        flow.updateTitle("Flow Goal")
        flow.selectCategory(.fitness)
        flow.updateMotivation("Move daily")

        let question = GoalQuestionDraft(
            text: "Did you complete today's workout?",
            responseType: .boolean,
            options: [],
            validationRules: ValidationRules(allowsEmpty: false),
            isActive: true,
            templateID: nil
        )
        flow.addCustomQuestion(question)

        flow.selectCadence(.daily)
        let added = flow.addReminderTime(ScheduleTime(hour: 8, minute: 30))
        #expect(added)
        #expect(flow.draft.schedule.reminderTimes.count == 1)

        let goal = try flow.saveGoal()
        #expect(goal.title == "Flow Goal")
        #expect(goal.questions.count == 1)
        #expect(goal.schedule.times.count == 1)
        #expect(goal.schedule.times.contains { $0.hour == 8 && $0.minute == 30 })

        let fetched = try context.fetch(FetchDescriptor<TrackingGoal>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == goal.id)
    }

    @Test("Flow reminder toggle enforces maximum count")
    func flowReminderToggleEnforcesMaximumCount() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let legacy = GoalCreationViewModel(modelContext: context)
        let flow = GoalCreationFlowViewModel(legacyViewModel: legacy)

        flow.selectCadence(.daily)
        let times = [
            ScheduleTime(hour: 8, minute: 0),
            ScheduleTime(hour: 12, minute: 30),
            ScheduleTime(hour: 18, minute: 45)
        ]

        times.forEach { time in
            let didAdd = flow.addReminderTime(time)
            #expect(didAdd)
        }
        #expect(flow.draft.schedule.reminderTimes.count == times.count)

        let extraTime = ScheduleTime(hour: 21, minute: 0)
        let didToggle = flow.toggleReminderTime(extraTime)
        #expect(!didToggle)
        #expect(flow.draft.schedule.reminderTimes.count == times.count)
    }
}