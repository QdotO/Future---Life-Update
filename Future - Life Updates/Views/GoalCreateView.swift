import SwiftData
import SwiftUI

@MainActor
struct GoalCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designStyle) private var designStyle

    @State private var showAllCategories = false
    @State private var newQuestionText: String = ""
    @State private var newResponseType: ResponseType = .numeric
    @State private var newQuestionMinimum: Double = 0
    @State private var newQuestionMaximum: Double = 100
    @State private var newQuestionAllowsEmpty: Bool = false
    @State private var newQuestionOptionsText: String = ""
    @State private var newReminderTime: Date =
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var conflictMessage: String?
    @State private var scheduleError: String?
    @State private var errorMessage: String?
    @FocusState private var focusedField: FocusTarget?

    @State private var viewModel: GoalCreationViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: GoalCreationViewModel(modelContext: modelContext))
    }

    private enum FocusTarget: Hashable {
        case title
        case description
        case customCategory
        case newQuestionPrompt
        case newQuestionMinimum
        case newQuestionMaximum
        case newQuestionOptions
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
                    goalDetailsCard
                    questionsCard
                    scheduleCard
                }
                .padding(AppTheme.BrutalistSpacing.md)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(!canSave)
                }
            }
            .alert(
                "Unable to Create Goal",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { seedNewQuestionDefaults(for: newResponseType) }
            .onChange(of: newResponseType) { _, newType in seedNewQuestionDefaults(for: newType) }
        }
        .environment(\.designStyle, .brutalist)
    }

    // MARK: - Cards

    private var goalDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            sectionTitle("Goal Details")

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                fieldLabel("Title")
                TextField("Title", text: $viewModel.title)
                    .focused($focusedField, equals: .title)
                    .brutalistField(isFocused: focusedField == .title)

                fieldLabel("Description")
                TextField("Description", text: $viewModel.goalDescription, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .focused($focusedField, equals: .description)
                    .brutalistField(isFocused: focusedField == .description)
            }

            Rectangle().fill(AppTheme.BrutalistPalette.border.opacity(0.25)).frame(height: 1)

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                fieldLabel("Category")

                LazyVGrid(
                    columns: categoryColumns, alignment: .leading,
                    spacing: AppTheme.BrutalistSpacing.sm
                ) {
                    ForEach(viewModel.primaryCategoryOptions) { option in
                        categoryButton(for: option)
                    }
                }

                if viewModel.hasOverflowCategories {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            showAllCategories.toggle()
                            if viewModel.selectedCategory == .custom {
                                focusedField = .customCategory
                            }
                        }
                        Haptics.selection()
                    } label: {
                        Text(showAllCategories ? "Hide extra categories" : "More categories")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .brutalistButton(style: .compactSecondary)
                }

                if showAllCategories {
                    LazyVGrid(
                        columns: categoryColumns, alignment: .leading,
                        spacing: AppTheme.BrutalistSpacing.sm
                    ) {
                        ForEach(viewModel.overflowCategoryOptions) { option in
                            categoryButton(for: option)
                        }
                    }
                }

                if viewModel.selectedCategory == .custom {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                        fieldLabel("Custom category name")
                        TextField(
                            "Name your category",
                            text: Binding(
                                get: { viewModel.customCategoryLabel },
                                set: { viewModel.updateCustomCategoryLabel($0) }
                            )
                        )
                        .focused($focusedField, equals: .customCategory)
                        .brutalistField(isFocused: focusedField == .customCategory)
                    }
                }
            }
        }
        .brutalistCard()
    }

    private var questionsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            sectionTitle("Questions")

            if viewModel.hasDraftQuestions {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    ForEach(Array(viewModel.draftQuestions.enumerated()), id: \.element.id) {
                        index, question in
                        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                            HStack {
                                fieldLabel("Prompt")
                                Spacer()
                                Toggle(
                                    "Active",
                                    isOn: Binding(
                                        get: { question.isActive }, set: { question.isActive = $0 })
                                ).labelsHidden()
                            }

                            TextField(
                                "Prompt",
                                text: Binding(get: { question.text }, set: { question.text = $0 }),
                                axis: .vertical
                            )
                            .lineLimit(2, reservesSpace: true)
                            .brutalistField(isFocused: false)

                            Picker(
                                selection: Binding(
                                    get: { question.responseType },
                                    set: { newType in
                                        question.responseType = newType
                                        seedValidationDefaults(for: question)
                                    })
                            ) {
                                ForEach(ResponseType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            } label: {
                                selectionField(
                                    "Response Type", value: question.responseType.displayName)
                            }
                            .pickerStyle(.menu)

                            questionConfigurationBindings(for: question)

                            HStack {
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.removeQuestion(question)
                                    Haptics.warning()
                                } label: {
                                    Label("Delete", systemImage: "trash").labelStyle(.titleAndIcon)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.red)
                            }
                        }
                        if index != viewModel.draftQuestions.count - 1 {
                            Rectangle().fill(AppTheme.BrutalistPalette.border.opacity(0.2)).frame(
                                height: 1)
                        }
                    }
                }
            } else {
                Text("Add a question to keep tracking your goal.")
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }

            Rectangle().fill(AppTheme.BrutalistPalette.border.opacity(0.25)).frame(height: 1)

            newQuestionComposer
        }
        .brutalistCard()
    }

    private var newQuestionComposer: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            fieldLabel("New Question")

            TextField("Ask a new question", text: $newQuestionText, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .focused($focusedField, equals: .newQuestionPrompt)
                .brutalistField(isFocused: focusedField == .newQuestionPrompt)

            Picker(selection: $newResponseType) {
                ForEach(ResponseType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                selectionField("Response Type", value: newResponseType.displayName)
            }
            .pickerStyle(.menu)

            newQuestionConfiguration

            Button {
                addQuestion()
            } label: {
                Text("Add Question").frame(maxWidth: .infinity)
            }
            .brutalistButton(style: .primary)
            .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var newQuestionConfiguration: some View {
        switch newResponseType {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                fieldLabel("Range")
                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        fieldLabel("Minimum")
                        TextField("Minimum", value: $newQuestionMinimum, format: .number)
                            .focused($focusedField, equals: .newQuestionMinimum)
                            .brutalistField(isFocused: focusedField == .newQuestionMinimum)
                            .platformNumericKeyboard()
                    }
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        fieldLabel("Maximum")
                        TextField("Maximum", value: $newQuestionMaximum, format: .number)
                            .focused($focusedField, equals: .newQuestionMaximum)
                            .brutalistField(isFocused: focusedField == .newQuestionMaximum)
                            .platformNumericKeyboard()
                    }
                }
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                fieldLabel("Options")
                Text("Comma separate each choice.")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                TextField("Options", text: $newQuestionOptionsText)
                    .focused($focusedField, equals: .newQuestionOptions)
                    .brutalistField(isFocused: focusedField == .newQuestionOptions)
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .text, .boolean, .time:
            Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
        }
    }

    @ViewBuilder
    private func questionConfigurationBindings(for question: Question) -> some View {
        switch question.responseType {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                fieldLabel("Range")
                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        fieldLabel("Minimum")
                        TextField(
                            "Minimum",
                            value: Binding(
                                get: {
                                    question.validationRules?.minimumValue
                                        ?? defaultMinimum(for: question.responseType)
                                },
                                set: { newValue in
                                    var rules =
                                        question.validationRules
                                        ?? ValidationRules(
                                            allowsEmpty: question.validationRules?.allowsEmpty
                                                ?? false)
                                    rules.minimumValue = newValue
                                    if let max = rules.maximumValue, max < newValue {
                                        rules.maximumValue = newValue
                                    }
                                    question.validationRules = rules
                                }),
                            format: .number
                        )
                        .brutalistField(isFocused: false)
                        .platformNumericKeyboard()
                    }
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        fieldLabel("Maximum")
                        TextField(
                            "Maximum",
                            value: Binding(
                                get: {
                                    question.validationRules?.maximumValue
                                        ?? defaultMaximum(for: question.responseType)
                                },
                                set: { newValue in
                                    var rules =
                                        question.validationRules
                                        ?? ValidationRules(
                                            allowsEmpty: question.validationRules?.allowsEmpty
                                                ?? false)
                                    let min =
                                        rules.minimumValue
                                        ?? defaultMinimum(for: question.responseType)
                                    rules.maximumValue = max(newValue, min)
                                    question.validationRules = rules
                                }),
                            format: .number
                        )
                        .brutalistField(isFocused: false)
                        .platformNumericKeyboard()
                    }
                }
                Toggle(
                    "Allow empty response",
                    isOn: Binding(
                        get: { question.validationRules?.allowsEmpty ?? false },
                        set: { newValue in
                            var rules =
                                question.validationRules ?? ValidationRules(allowsEmpty: newValue)
                            rules.allowsEmpty = newValue
                            question.validationRules = rules
                        })
                )
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                fieldLabel("Options")
                Text("Comma separate each choice.")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                TextField(
                    "Options",
                    text: Binding(
                        get: { (question.options ?? []).joined(separator: ", ") },
                        set: { newValue in
                            question.options = parseOptions(from: newValue)
                        }
                    )
                )
                .brutalistField(isFocused: false)
                Toggle(
                    "Allow empty response",
                    isOn: Binding(
                        get: { question.validationRules?.allowsEmpty ?? false },
                        set: { newValue in
                            var rules =
                                question.validationRules ?? ValidationRules(allowsEmpty: newValue)
                            rules.allowsEmpty = newValue
                            question.validationRules = rules
                        })
                )
            }
        case .text, .boolean, .time:
            Toggle(
                "Allow empty response",
                isOn: Binding(
                    get: { question.validationRules?.allowsEmpty ?? false },
                    set: { newValue in
                        var rules =
                            question.validationRules ?? ValidationRules(allowsEmpty: newValue)
                        rules.allowsEmpty = newValue
                        question.validationRules = rules
                    })
            )
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            sectionTitle("Schedule")

            Picker(
                selection: Binding(
                    get: { viewModel.scheduleDraft.frequency },
                    set: { newValue in
                        viewModel.setFrequency(newValue)
                        scheduleError = nil
                        conflictMessage = viewModel.conflictDescription()
                        if conflictMessage != nil { Haptics.warning() } else { Haptics.selection() }
                    })
            ) {
                ForEach(Frequency.allCases, id: \.self) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            } label: {
                selectionField("Frequency", value: viewModel.scheduleDraft.frequency.displayName)
            }
            .pickerStyle(.menu)

            switch viewModel.scheduleDraft.frequency {
            case .weekly:
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    WeekdaySelector(
                        selectedWeekdays: Binding(
                            get: { viewModel.scheduleDraft.selectedWeekdays },
                            set: { viewModel.updateSelectedWeekdays($0) }))
                    if viewModel.scheduleDraft.selectedWeekdays.isEmpty {
                        Text("Select at least one day to send reminders.")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }
            case .custom:
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    fieldLabel("Interval (days)")
                    IntervalPicker(
                        interval: Binding(
                            get: { viewModel.scheduleDraft.intervalDayCount ?? 3 },
                            set: { viewModel.updateIntervalDayCount($0) }))
                }
            default:
                EmptyView()
            }

            Picker(
                selection: Binding(
                    get: { viewModel.scheduleDraft.timezone }, set: { viewModel.setTimezone($0) })
            ) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                    if let tz = TimeZone(identifier: identifier) {
                        Text(timezoneDisplayName(tz)).tag(tz)
                    }
                }
            } label: {
                selectionField(
                    "Timezone", value: timezoneDisplayName(viewModel.scheduleDraft.timezone))
            }
            .pickerStyle(.menu)

            if let conflictMessage { ConflictBanner(message: conflictMessage) }
            if let scheduleError {
                Text(scheduleError).font(AppTheme.BrutalistTypography.caption).foregroundColor(.red)
            }

            if viewModel.scheduleDraft.times.isEmpty {
                Text("Add at least one reminder time to stay on track.")
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    ForEach(Array(viewModel.scheduleDraft.times.enumerated()), id: \.offset) {
                        index, time in
                        reminderRow(index: index, time: time)
                    }
                }
            }

            Button {
                if viewModel.addScheduleTime(from: newReminderTime) {
                    Haptics.selection()
                    scheduleError = nil
                    conflictMessage = viewModel.conflictDescription()
                    newReminderTime =
                        Calendar.current.date(byAdding: .minute, value: 30, to: newReminderTime)
                        ?? newReminderTime
                } else {
                    scheduleError = "Reminders must be at least 5 minutes apart."
                    Haptics.warning()
                }
            } label: {
                Text("Add Reminder Time").frame(maxWidth: .infinity)
            }
            .brutalistButton(style: .secondary)

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                fieldLabel("New Reminder")
                DatePicker("", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                    .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                    .background(AppTheme.BrutalistPalette.background)
                    .overlay(
                        Rectangle().stroke(
                            AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.standard))
            }

            Text("Times shown in \(timezoneDisplayName(viewModel.scheduleDraft.timezone)).")
                .font(AppTheme.BrutalistTypography.caption)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .brutalistCard()
    }

    private func reminderRow(index: Int, time: ScheduleTime) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            fieldLabel("Reminder \(index + 1)")
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { reminderDate(for: time) },
                        set: { newValue in
                            let newTime = ScheduleTime(
                                components: Calendar.current.dateComponents(
                                    [.hour, .minute], from: newValue))
                            var replaced = false
                            // Try replace by removing old then adding new; revert if conflict
                            let old = time
                            viewModel.removeScheduleTime(old)
                            if viewModel.addScheduleTime(from: newValue) {
                                replaced = true
                                scheduleError = nil
                                conflictMessage = viewModel.conflictDescription()
                            } else {
                                // revert
                                _ = viewModel.addScheduleTime(from: reminderDate(for: old))
                                scheduleError = "Reminders must be at least 5 minutes apart."
                                conflictMessage = viewModel.conflictDescription()
                                Haptics.warning()
                            }
                            if replaced { Haptics.selection() }
                        }),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                .background(AppTheme.BrutalistPalette.background)
                .overlay(
                    Rectangle().stroke(
                        AppTheme.BrutalistPalette.border,
                        lineWidth: AppTheme.BrutalistBorder.standard))

                Button(role: .destructive) {
                    viewModel.removeScheduleTime(time)
                    scheduleError = nil
                    conflictMessage = viewModel.conflictDescription()
                    Haptics.selection()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(AppTheme.BrutalistPalette.background)
                        .overlay(
                            Rectangle().stroke(
                                AppTheme.BrutalistPalette.border,
                                lineWidth: AppTheme.BrutalistBorder.standard))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.selectedCategory != nil
            && viewModel.hasDraftQuestions
    }

    private var categoryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: AppTheme.BrutalistSpacing.sm)]
    }

    private func categoryButton(for option: GoalCreationViewModel.CategoryOption) -> some View {
        let isSelected: Bool = {
            switch option {
            case .system(let category):
                return viewModel.selectedCategory == category
            case .custom(let label):
                guard viewModel.selectedCategory == .custom else { return false }
                let trimmed = viewModel.customCategoryLabel.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && trimmed.caseInsensitiveCompare(label) == .orderedSame
            }
        }()

        return Button {
            Haptics.selection()
            viewModel.selectCategory(option)
            if option.isCustom {
                showAllCategories = true
                focusedField = .customCategory
            }
        } label: {
            Text(option.title).frame(maxWidth: .infinity, alignment: .center)
        }
        .brutalistButton(style: isSelected ? .primary : .compactSecondary)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTheme.BrutalistTypography.overline)
            .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTheme.BrutalistTypography.overline)
            .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func selectionField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            fieldLabel(title)
            HStack {
                Text(value).font(AppTheme.BrutalistTypography.bodyBold)
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
            }
            .padding(.vertical, AppTheme.BrutalistSpacing.sm)
            .padding(.horizontal, AppTheme.BrutalistSpacing.md)
            .background(AppTheme.BrutalistPalette.background)
            .overlay(
                Rectangle().stroke(
                    AppTheme.BrutalistPalette.border, lineWidth: AppTheme.BrutalistBorder.standard))
        }
    }

    private func reminderDate(for time: ScheduleTime) -> Date {
        var comps = time.dateComponents
        comps.year = 2000
        comps.month = 1
        comps.day = 1
        var cal = Calendar.current
        cal.timeZone = viewModel.scheduleDraft.timezone
        return cal.date(from: comps) ?? Date()
    }

    private func timezoneDisplayName(_ timezone: TimeZone) -> String {
        timezone.localizedName(for: .shortGeneric, locale: .current) ?? timezone.identifier
    }

    private func defaultMinimum(for responseType: ResponseType) -> Double {
        switch responseType {
        case .scale: return 1
        case .waterIntake: return 0
        default: return 0
        }
    }
    private func defaultMaximum(for responseType: ResponseType) -> Double {
        switch responseType {
        case .scale: return 10
        case .waterIntake: return 128
        default: return 100
        }
    }

    private func seedValidationDefaults(for question: Question) {
        let allows = question.validationRules?.allowsEmpty ?? false
        switch question.responseType {
        case .numeric:
            question.options = []
            question.validationRules = ValidationRules(
                minimumValue: 0, maximumValue: 100, allowsEmpty: allows)
        case .scale:
            question.options = []
            question.validationRules = ValidationRules(
                minimumValue: 1, maximumValue: 10, allowsEmpty: allows)
        case .slider:
            question.options = []
            question.validationRules = ValidationRules(
                minimumValue: 0, maximumValue: 100, allowsEmpty: allows)
        case .waterIntake:
            question.options = []
            question.validationRules = ValidationRules(
                minimumValue: 0, maximumValue: 128, allowsEmpty: allows)
        case .multipleChoice:
            question.options = []
            question.validationRules = ValidationRules(allowsEmpty: allows)
        case .text, .boolean, .time:
            question.options = []
            question.validationRules = allows ? ValidationRules(allowsEmpty: true) : nil
        }
    }

    private func seedNewQuestionDefaults(for type: ResponseType) {
        newQuestionAllowsEmpty = false
        newQuestionOptionsText = ""
        switch type {
        case .numeric:
            newQuestionMinimum = 0
            newQuestionMaximum = 100
        case .scale:
            newQuestionMinimum = 1
            newQuestionMaximum = 10
        case .slider:
            newQuestionMinimum = 0
            newQuestionMaximum = 100
        case .waterIntake:
            newQuestionMinimum = 0
            newQuestionMaximum = 128
        case .multipleChoice, .text, .boolean, .time:
            break
        }
    }

    private func addQuestion() {
        let trimmed = newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var options: [String]? = nil
        var rules: ValidationRules? = nil

        switch newResponseType {
        case .multipleChoice:
            let parsed = parseOptions(from: newQuestionOptionsText)
            guard !parsed.isEmpty else {
                errorMessage = "Add at least one option before saving."
                Haptics.warning()
                return
            }
            options = parsed
            rules = ValidationRules(allowsEmpty: newQuestionAllowsEmpty)
        case .numeric, .scale, .slider, .waterIntake:
            let minVal = min(newQuestionMinimum, newQuestionMaximum)
            let maxVal = max(newQuestionMinimum, newQuestionMaximum)
            rules = ValidationRules(
                minimumValue: minVal, maximumValue: maxVal, allowsEmpty: newQuestionAllowsEmpty)
        case .text, .boolean, .time:
            rules = newQuestionAllowsEmpty ? ValidationRules(allowsEmpty: true) : nil
        }

        _ = viewModel.addManualQuestion(
            text: trimmed,
            responseType: newResponseType,
            options: options,
            validationRules: rules
        )

        Haptics.selection()
        newQuestionText = ""
        newResponseType = .numeric
        seedNewQuestionDefaults(for: .numeric)
    }

    private func parseOptions(from text: String) -> [String] {
        let tokens = text.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        var result: [String] = []
        var seen: Set<String> = []
        for item in tokens where !seen.contains(item.lowercased()) {
            seen.insert(item.lowercased())
            result.append(item)
        }
        return result
    }

    private func handleSave() {
        do {
            let goal = try viewModel.createGoal()
            Haptics.success()
            NotificationScheduler.shared.scheduleNotifications(for: goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        return GoalCreateView(modelContext: context).modelContainer(container)
    } else {
        return Text("Preview Error Loading Sample Data")
    }
}
