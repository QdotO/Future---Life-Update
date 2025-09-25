import Foundation
import Testing
import SwiftData
import Observation
@testable import Future___Life_Updates

@MainActor
struct PhaseOneFeatureTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("TrackingGoal initializes with expected defaults")
    func trackingGoalInitializationDefaults() throws {
        let goal = TrackingGoal(title: "Hydration", description: "Drink more water", category: .health)

        #expect(goal.isActive)
        #expect(goal.questions.isEmpty)
        #expect(goal.schedule.frequency == .daily)
        #expect(goal.schedule.times.isEmpty)
        #expect(goal.createdAt <= goal.updatedAt)
        #expect(goal.customCategoryLabel == nil)
    }

    @Test("Schedule defaults produce empty weekday selections")
    func scheduleDefaultsSelectedWeekdays() {
        let schedule = Schedule(frequency: .weekly)
        #expect(schedule.selectedWeekdays.isEmpty)

        let deduplicated = Schedule(
            frequency: .weekly,
            selectedWeekdays: [.monday, .monday, .tuesday]
        )
        #expect(deduplicated.selectedWeekdays == [.monday, .tuesday])
    }

    @Test("GoalCreationViewModel persists configured goal")
    func goalCreationPersistsGoalWithQuestions() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let fixedStartDate = Date(timeIntervalSince1970: 1000)
        let viewModel = GoalCreationViewModel(modelContext: context, dateProvider: { fixedStartDate })

        viewModel.title = "Hydration"
        viewModel.goalDescription = "Drink eight glasses"
        viewModel.selectedCategory = .health

        let question = viewModel.addManualQuestion(text: "How many glasses did you drink today?", responseType: .numeric)
        #expect(question.text == "How many glasses did you drink today?")

        viewModel.updateSchedule(
            frequency: .daily,
            times: [DateComponents(hour: 9, minute: 0)],
            timezone: TimeZone(identifier: "America/Los_Angeles")!
        )

        let persistedGoal = try viewModel.createGoal()
        try context.save()

        let persistedGoalID = persistedGoal.id
        let descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate<TrackingGoal> { goal in
            goal.id == persistedGoalID
        }, sortBy: [SortDescriptor(\.createdAt)])
        let fetchedGoals = try context.fetch(descriptor)
        #expect(fetchedGoals.count == 1)

        guard let fetchedGoal = fetchedGoals.first else {
            Issue.record("Expected to fetch the created goal")
            return
        }

        #expect(fetchedGoal.questions.count == 1)
        #expect(fetchedGoal.schedule.times.count == 1)
        #expect(fetchedGoal.schedule.times.first?.hour == 9)
        #expect(fetchedGoal.schedule.timezoneIdentifier == "America/Los_Angeles")
        #expect(fetchedGoal.title == "Hydration")
        #expect(fetchedGoal.schedule.startDate == fixedStartDate)
    }

    @Test("Question upsert replaces existing draft while preserving identity")
    func questionComposerUpsertUpdatesExistingQuestions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let viewModel = GoalCreationViewModel(modelContext: context)

        let original = viewModel.addManualQuestion(
            text: "How many glasses did you drink today?",
            responseType: .numeric,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 12, allowsEmpty: false)
        )

        #expect(viewModel.hasDraftQuestions)
        #expect(viewModel.draftQuestions.count == 1)

        let updated = viewModel.upsertQuestion(
            id: original.id,
            text: "Which beverage did you enjoy?",
            responseType: .multipleChoice,
            options: ["Water", "Tea", "Juice"],
            validationRules: ValidationRules(allowsEmpty: true)
        )

        #expect(viewModel.draftQuestions.count == 1)
        #expect(updated.id == original.id)
        #expect(updated.text == "Which beverage did you enjoy?")
        #expect(updated.responseType == .multipleChoice)
        #expect(updated.options == ["Water", "Tea", "Juice"])
        #expect(updated.validationRules?.allowsEmpty == true)

        let numericReset = viewModel.upsertQuestion(
            id: updated.id,
            text: "How many ounces did you drink?",
            responseType: .numeric,
            options: nil,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 64, allowsEmpty: false)
        )

        #expect(viewModel.draftQuestions.count == 1)
        #expect(numericReset.options == nil)
        #expect(numericReset.validationRules?.maximumValue == 64)
        #expect(numericReset.responseType == .numeric)
    }

    @Test("GoalCreationViewModel surfaces scheduling conflicts")
    func goalCreationDetectsSchedulingConflicts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let existingSchedule = Schedule(
            startDate: Date(),
            frequency: .daily,
            times: [ScheduleTime(hour: 9, minute: 0)],
            timezoneIdentifier: TimeZone.current.identifier
        )
        let existingGoal = TrackingGoal(title: "Existing", description: "", category: .health, schedule: existingSchedule)
        existingSchedule.goal = existingGoal
        context.insert(existingGoal)
        try context.save()

        let viewModel = GoalCreationViewModel(modelContext: context)
        let reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let didAdd = viewModel.addScheduleTime(from: reminderDate)
        #expect(didAdd)
        let conflictDescription = viewModel.conflictDescription()
        #expect(conflictDescription?.contains("Existing") == true)
    }

    @Test("Category picker exposes custom options and persists labels")
    func categoryPickerSupportsCustomLabels() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let wellnessSchedule = Schedule()
        let wellnessGoal = TrackingGoal(
            title: "Morning Yoga",
            description: "",
            category: .custom,
            customCategoryLabel: "Wellness",
            schedule: wellnessSchedule
        )
        wellnessSchedule.goal = wellnessGoal

        let financeSchedule = Schedule()
        let financeGoal = TrackingGoal(
            title: "Investing",
            description: "",
            category: .custom,
            customCategoryLabel: "Finance Goals",
            schedule: financeSchedule
        )
        financeSchedule.goal = financeGoal

        context.insert(wellnessGoal)
        context.insert(financeGoal)
        try context.save()

        let viewModel = GoalCreationViewModel(modelContext: context)

        #expect(viewModel.primaryCategoryOptions.count == GoalCreationViewModel.primaryCategoryLimit)
        let primaryTitles = viewModel.primaryCategoryOptions.map { $0.title }
        #expect(primaryTitles.contains(TrackingCategory.health.displayName))
        #expect(primaryTitles.contains(TrackingCategory.learning.displayName))

        let overflowTitles = viewModel.overflowCategoryOptions.map { $0.title }
        #expect(overflowTitles.contains(TrackingCategory.social.displayName))
        #expect(overflowTitles.contains(TrackingCategory.finance.displayName))
        #expect(overflowTitles.contains("Wellness"))
        #expect(overflowTitles.contains("Finance Goals"))

        viewModel.selectCategory(.system(.finance))
        #expect(viewModel.selectedCategory == .finance)
        #expect(viewModel.customCategoryLabel.isEmpty)

        viewModel.updateCustomCategoryLabel("Mindfulness")
        #expect(viewModel.selectedCategory == .custom)
        #expect(viewModel.customCategoryLabel == "Mindfulness")

        let containsMindfulness = viewModel.primaryCategoryOptions.contains { option in
            if case .custom(let label) = option {
                return label == "Mindfulness"
            }
            return false
        } || viewModel.overflowCategoryOptions.contains { option in
            if case .custom(let label) = option {
                return label == "Mindfulness"
            }
            return false
        }
        #expect(containsMindfulness)

        viewModel.title = "Meditation"
        viewModel.goalDescription = "Daily meditation reflection"
        viewModel.addManualQuestion(text: "How present did you feel?", responseType: .text)
        viewModel.updateSchedule(
            frequency: .daily,
            times: [DateComponents(hour: 7, minute: 30)],
            timezone: TimeZone.current
        )

        let savedGoal = try viewModel.createGoal()
        #expect(savedGoal.category == .custom)
        #expect(savedGoal.customCategoryLabel == "Mindfulness")
    }

    @Test("DataEntryViewModel overwrites same-day responses")
    func dataEntryViewModelOverwritesSameDayResponses() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let fixedDate = Date(timeIntervalSince1970: 2000)

        let goal = TrackingGoal(title: "Hydration", description: "Daily water intake", category: .health)
        let question = Question(text: "How many glasses?", responseType: .numeric)
        goal.questions = [question]
        goal.schedule = Schedule()
        goal.schedule.goal = goal
        question.goal = goal
        context.insert(goal)
        try context.save()

    let viewModel = DataEntryViewModel(goal: goal, modelContext: context, dateProvider: { fixedDate })
    viewModel.updateNumericResponse(8, for: question)
        try viewModel.saveEntries()

    viewModel.updateNumericResponse(10, for: question)
        try viewModel.saveEntries()
        let goalIdentifier = goal.persistentModelID
        let questionIdentifier = question.persistentModelID

        let descriptor = FetchDescriptor<DataPoint>(predicate: #Predicate<DataPoint> { dataPoint in
            dataPoint.goal?.persistentModelID == goalIdentifier &&
            dataPoint.question?.persistentModelID == questionIdentifier
        })
        let points = try context.fetch(descriptor)

        #expect(points.count == 1)
        #expect(points.first?.numericValue == 10)
        #expect(Calendar.current.isDate(points.first?.timestamp ?? .distantPast, inSameDayAs: fixedDate))
    }

    @Test("GoalEditorViewModel prevents overlapping reminders")
    func goalEditorPreventsReminderConflicts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let schedule = Schedule(
            startDate: Date(),
            frequency: .daily,
            times: [ScheduleTime(hour: 9, minute: 0), ScheduleTime(hour: 10, minute: 0)],
            timezoneIdentifier: TimeZone.current.identifier
        )
        let goal = TrackingGoal(title: "Hydration", description: "", category: .health, schedule: schedule)
        schedule.goal = goal
        context.insert(goal)
        try context.save()

        let viewModel = GoalEditorViewModel(goal: goal, modelContext: context)
        let conflictingDate = Calendar.current.date(bySettingHour: 9, minute: 2, second: 0, of: Date()) ?? Date()
        let wasUpdated = viewModel.updateScheduleTime(at: 1, to: conflictingDate)
        #expect(!wasUpdated)
        #expect(viewModel.scheduleDraft.times.contains(where: { $0.hour == 10 && $0.minute == 0 }))
    }

    @Test("DataEntryViewModel handles all response types")
    func dataEntryViewModelHandlesAllResponseTypes() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let fixedDate = Date(timeIntervalSince1970: 3000)

        let numericQuestion = Question(text: "Numeric", responseType: .numeric, validationRules: ValidationRules(minimumValue: 0, maximumValue: 100, allowsEmpty: false))
        let scaleQuestion = Question(text: "Scale", responseType: .scale, validationRules: ValidationRules(minimumValue: 1, maximumValue: 10, allowsEmpty: false))
        let sliderQuestion = Question(text: "Slider", responseType: .slider, validationRules: ValidationRules(minimumValue: 0, maximumValue: 1, allowsEmpty: false))
        let booleanQuestion = Question(text: "Did you succeed?", responseType: .boolean)
        let textQuestion = Question(text: "Describe your progress", responseType: .text, validationRules: ValidationRules(allowsEmpty: false))
        let multiQuestion = Question(text: "Select blockers", responseType: .multipleChoice, options: ["Time", "Energy", "Resources"], validationRules: ValidationRules(allowsEmpty: false))
        let timeQuestion = Question(text: "When did you start?", responseType: .time)

        let goal = TrackingGoal(title: "Daily Reflection", description: "Log all answer types", category: .productivity)
        goal.schedule = Schedule()
        goal.schedule.goal = goal
        goal.questions = [numericQuestion, scaleQuestion, sliderQuestion, booleanQuestion, textQuestion, multiQuestion, timeQuestion]
        for question in goal.questions {
            question.goal = goal
        }
        context.insert(goal)
        try context.save()

        let viewModel = DataEntryViewModel(goal: goal, modelContext: context, dateProvider: { fixedDate })

        viewModel.updateNumericResponse(42, for: numericQuestion)
        viewModel.updateNumericResponse(7, for: scaleQuestion)
        viewModel.updateNumericResponse(1, for: sliderQuestion)
        viewModel.updateBooleanResponse(true, for: booleanQuestion)
        viewModel.updateTextResponse("Feeling great", for: textQuestion)
        viewModel.setOption("Energy", isSelected: true, for: multiQuestion)
        let recordedTime = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: fixedDate) ?? fixedDate
        viewModel.updateTimeResponse(recordedTime, for: timeQuestion)

        #expect(viewModel.canSubmit)
        try viewModel.saveEntries()

        let descriptor = FetchDescriptor<DataPoint>()
        let dataPoints = try context.fetch(descriptor).filter { dataPoint in
            dataPoint.goal?.persistentModelID == goal.persistentModelID
        }
        #expect(dataPoints.count == goal.questions.count)

        let pointsByQuestion = Dictionary(uniqueKeysWithValues: dataPoints.compactMap { dataPoint -> (UUID, DataPoint)? in
            guard let id = dataPoint.question?.id else { return nil }
            return (id, dataPoint)
        })

        #expect(pointsByQuestion[numericQuestion.id]?.numericValue == 42)
        #expect(pointsByQuestion[scaleQuestion.id]?.numericValue == 7)
    #expect(pointsByQuestion[sliderQuestion.id]?.numericValue == 1)
        #expect(pointsByQuestion[booleanQuestion.id]?.boolValue == true)
        #expect(pointsByQuestion[textQuestion.id]?.textValue == "Feeling great")
        #expect(pointsByQuestion[multiQuestion.id]?.selectedOptions == ["Energy"])
        if let storedTime = pointsByQuestion[timeQuestion.id]?.timeValue {
            #expect(Calendar.current.component(.hour, from: storedTime) == 21)
            #expect(Calendar.current.component(.minute, from: storedTime) == 30)
        } else {
            Issue.record("Expected time response to be stored")
        }
    }

    @Test("Scale responses accumulate into running totals")
    func scaleResponsesAccumulateIntoRunningTotals() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let goal = TrackingGoal(title: "Hydration", description: "Track water intake", category: .health)
        goal.schedule = Schedule()
        goal.schedule.goal = goal

        let scaleQuestion = Question(
            text: "Glasses of water",
            responseType: .scale,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 20, allowsEmpty: false)
        )
        scaleQuestion.goal = goal
        goal.questions = [scaleQuestion]

        context.insert(goal)
        try context.save()

        var currentDate = calendar.date(from: DateComponents(year: 2025, month: 4, day: 1, hour: 8))!
        let baseDate = currentDate
        let viewModel = DataEntryViewModel(
            goal: goal,
            modelContext: context,
            dateProvider: {
                defer { currentDate = calendar.date(byAdding: .hour, value: 1, to: currentDate)! }
                return currentDate
            },
            calendar: calendar
        )

        viewModel.updateNumericResponse(3, for: scaleQuestion)
        try viewModel.saveEntries()

        viewModel.updateNumericResponse(2, for: scaleQuestion)
        try viewModel.saveEntries()

        let descriptor = FetchDescriptor<DataPoint>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let points = try context.fetch(descriptor)

        #expect(points.count == 2)
        #expect(points[0].numericValue == 3)
        #expect(points[0].numericDelta == 3)
        #expect(points[1].numericValue == 5)
        #expect(points[1].numericDelta == 2)

        #expect(calendar.isDate(points[0].timestamp, inSameDayAs: baseDate))
    }

    @Test("Goal history groups entries by day with deltas")
    func goalHistoryGroupsEntriesByDayWithDeltas() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let goal = TrackingGoal(title: "Activity", description: "Track exercise reps", category: .health)
        goal.schedule = Schedule()
        goal.schedule.goal = goal

        let scaleQuestion = Question(
            text: "Push-ups",
            responseType: .scale,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 100, allowsEmpty: false)
        )
        scaleQuestion.goal = goal
        goal.questions = [scaleQuestion]

        let baseDate = calendar.date(from: DateComponents(year: 2025, month: 5, day: 10, hour: 9))!
        let laterSameDay = calendar.date(byAdding: .hour, value: 3, to: baseDate)!
        let previousDay = calendar.date(byAdding: .day, value: -1, to: baseDate)!

        let points = [
            DataPoint(goal: goal, question: scaleQuestion, timestamp: baseDate, numericValue: 3, numericDelta: 3),
            DataPoint(goal: goal, question: scaleQuestion, timestamp: laterSameDay, numericValue: 5, numericDelta: 2),
            DataPoint(goal: goal, question: scaleQuestion, timestamp: previousDay, numericValue: 4, numericDelta: 4)
        ]

        goal.dataPoints.append(contentsOf: points)
        scaleQuestion.dataPoints.append(contentsOf: points)
        points.forEach { context.insert($0) }
        try context.save()

        let viewModel = GoalHistoryViewModel(
            goal: goal,
            modelContext: context,
            dateProvider: { laterSameDay },
            calendar: calendar
        )

        #expect(viewModel.sections.count == 2)

        guard let latestSection = viewModel.sections.first else {
            Issue.record("Expected a section for the latest day")
            return
        }

        #expect(calendar.isDate(latestSection.date, inSameDayAs: baseDate))
        #expect(latestSection.entries.count == 2)
        #expect(latestSection.entries.first?.responseSummary == "3 -> 5")
        #expect(latestSection.entries.last?.responseSummary == "0 -> 3")

        guard viewModel.sections.count > 1 else {
            Issue.record("Expected a section for the previous day")
            return
        }

        let previousSection = viewModel.sections[1]
        #expect(calendar.isDate(previousSection.date, inSameDayAs: previousDay))
        #expect(previousSection.entries.count == 1)
        #expect(previousSection.entries.first?.responseSummary == "0 -> 4")
    }

    @Test("GoalEditorViewModel updates schedule and questions")
    func goalEditorViewModelUpdatesScheduleAndQuestions() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let schedule = Schedule(startDate: Date(timeIntervalSince1970: 100), frequency: .daily, times: [ScheduleTime(hour: 9, minute: 0)])
        let existingQuestion = Question(text: "How many pages did you read?", responseType: .numeric, validationRules: ValidationRules(minimumValue: 0, maximumValue: 200, allowsEmpty: false))

        let goal = TrackingGoal(title: "Reading", description: "Read more", category: .learning, schedule: schedule)
        schedule.goal = goal
        existingQuestion.goal = goal
        goal.questions = [existingQuestion]
        context.insert(goal)
        try context.save()

        let editor = GoalEditorViewModel(goal: goal, modelContext: context)
        editor.title = "Updated Reading Habit"
        editor.goalDescription = "Track pages and motivation"
        editor.selectedCategory = .learning
    editor.scheduleDraft.frequency = .weekly
    let timezone = TimeZone(identifier: "America/New_York") ?? .current
    editor.scheduleDraft.timezone = timezone
        editor.scheduleDraft.times = [ScheduleTime(hour: 8, minute: 30), ScheduleTime(hour: 20, minute: 0)]

        editor.questionDrafts[0].text = "What motivated you today?"
        editor.questionDrafts[0].responseType = .multipleChoice
        editor.questionDrafts[0].options = ["Story", "Characters"]
        editor.questionDrafts[0].validationRules = ValidationRules(allowsEmpty: false)

        editor.addQuestion(
            text: "Did you read before bed?",
            responseType: .boolean,
            options: nil,
            validationRules: ValidationRules(allowsEmpty: false)
        )

        let updatedGoal = try editor.saveChanges()

        #expect(updatedGoal.title == "Updated Reading Habit")
        #expect(updatedGoal.goalDescription == "Track pages and motivation")
        #expect(updatedGoal.schedule.frequency == .weekly)
        #expect(updatedGoal.schedule.times.count == 2)
    #expect(updatedGoal.schedule.timezoneIdentifier == timezone.identifier)

        guard let motivationQuestion = updatedGoal.questions.first(where: { $0.text == "What motivated you today?" }) else {
            Issue.record("Expected updated question to exist")
            return
        }

        #expect(motivationQuestion.responseType == .multipleChoice)
        #expect(motivationQuestion.options == ["Story", "Characters"])

        #expect(updatedGoal.questions.contains(where: { $0.text == "Did you read before bed?" }))
    }

    @Test("Newly created goal retains metadata after first log")
    func newGoalRetainsMetadataAfterLogging() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let creationDate = Date(timeIntervalSince1970: 4_000)
        let creationViewModel = GoalCreationViewModel(modelContext: context, dateProvider: { creationDate })
        creationViewModel.title = "Daily Stretch"
        creationViewModel.goalDescription = "Loosen up and avoid stiffness"
        creationViewModel.selectedCategory = .fitness
        creationViewModel.addManualQuestion(
            text: "How many minutes did you stretch?",
            responseType: .numeric,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 120, allowsEmpty: false)
        )

        let goal = try creationViewModel.createGoal()

        guard let question = goal.questions.first else {
            Issue.record("Expected goal to include the created question")
            return
        }

        let entryDate = Date(timeIntervalSince1970: 4_500)
        let dataEntry = DataEntryViewModel(goal: goal, modelContext: context, dateProvider: { entryDate })
        dataEntry.updateNumericResponse(15, for: question)
        try dataEntry.saveEntries()

        #expect(goal.title == "Daily Stretch")
        #expect(goal.goalDescription == "Loosen up and avoid stiffness")
    }
}
