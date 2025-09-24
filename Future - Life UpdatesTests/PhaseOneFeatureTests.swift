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
}
