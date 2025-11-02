import SwiftData
import SwiftUI

struct GoalEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designStyle) private var designStyle

    @State private var newQuestionText: String = ""
    @State private var newQuestionOptionsText: String = ""
    @State private var newQuestionMinimum: Double = 0
    @State private var newQuestionMaximum: Double = 100
    @State private var newQuestionAllowsEmpty: Bool = false
    @State private var newResponseType: ResponseType = .numeric
    @State private var newReminderTime: Date =
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var errorMessage: String?
    @State private var didSeedNewQuestionDefaults = false
    @State private var conflictMessage: String?
    @State private var scheduleError: String?
    @State private var showAllCategories = false
    @FocusState private var focusedField: FocusTarget?

    @Bindable private var viewModel: GoalEditorViewModel

    init(viewModel: GoalEditorViewModel) {
        self._viewModel = Bindable(viewModel)
    }

    private enum FocusTarget: Hashable {
        case title
        case description
        case customCategory
        case questionPrompt(UUID)
        case questionMinimum(UUID)
        case questionMaximum(UUID)
        case questionOptions(UUID)
        case newQuestionPrompt
        case newQuestionMinimum
        case newQuestionMaximum
        case newQuestionOptions
    }

    private var legacyEditor: some View {
        Form {
            goalDetailsSection
            questionsSection
            scheduleSection
        }
    }

    private var brutalistEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
                brutalistGoalDetailsCard
                brutalistQuestionsCard
                brutalistScheduleCard
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
    }

    private var brutalistGoalDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            brutalistSectionTitle("Goal Details")

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                brutalistFieldLabel("Title")
                TextField("Title", text: $viewModel.title)
                    .focused($focusedField, equals: .title)
                    .brutalistField(isFocused: focusedField == .title)
                    .textContentType(.nickname)

                brutalistFieldLabel("Description")
                TextField("Description", text: $viewModel.goalDescription, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .focused($focusedField, equals: .description)
                    .brutalistField(isFocused: focusedField == .description)
            }

            Rectangle()
                .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                brutalistFieldLabel("Category")

                LazyVGrid(
                    columns: categoryColumns, alignment: .leading,
                    spacing: AppTheme.BrutalistSpacing.sm
                ) {
                    ForEach(categoryOptionsToDisplay) { option in
                        brutalistCategoryButton(for: option)
                    }
                }

                if hasOverflowCategories {
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

                if viewModel.selectedCategory == .custom {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                        brutalistFieldLabel("Custom category name")
                        TextField(
                            "Name your category",
                            text: Binding(
                                get: { viewModel.customCategoryLabel },
                                set: { newValue in
                                    viewModel.updateCustomCategoryLabel(newValue)
                                }
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

    private var categoryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: AppTheme.BrutalistSpacing.sm)]
    }

    private var allCategoryOptions: [GoalCreationViewModel.CategoryOption] {
        viewModel.primaryCategoryOptions + viewModel.overflowCategoryOptions
    }

    private var categoryOptionsToDisplay: [GoalCreationViewModel.CategoryOption] {
        showAllCategories ? allCategoryOptions : viewModel.primaryCategoryOptions
    }

    private var hasOverflowCategories: Bool {
        !viewModel.overflowCategoryOptions.isEmpty
    }

    private var shouldAutoExpandCategories: Bool {
        guard hasOverflowCategories else { return false }
        if viewModel.selectedCategory == .custom { return true }
        let selectedOption = GoalCreationViewModel.CategoryOption.system(viewModel.selectedCategory)
        return viewModel.overflowCategoryOptions.contains(selectedOption)
    }

    private func brutalistCategoryButton(for option: GoalCreationViewModel.CategoryOption)
        -> some View
    {
        let isSelected = isOptionSelected(option)

        return Button {
            Haptics.selection()
            viewModel.selectCategory(option)
            if option.isCustom {
                showAllCategories = true
                focusedField = .customCategory
            }
        } label: {
            Text(option.title)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .brutalistButton(style: isSelected ? .primary : .compactSecondary)
    }

    private func isOptionSelected(_ option: GoalCreationViewModel.CategoryOption) -> Bool {
        switch option {
        case .system(let category):
            return viewModel.selectedCategory == category
        case .custom(let label):
            guard viewModel.selectedCategory == .custom else { return false }
            let trimmedLabel = viewModel.customCategoryLabel.trimmingCharacters(
                in: .whitespacesAndNewlines)
            return !trimmedLabel.isEmpty
                && trimmedLabel.caseInsensitiveCompare(label) == .orderedSame
        }
    }

    private func brutalistSectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTheme.BrutalistTypography.overline)
            .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func brutalistFieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTheme.BrutalistTypography.overline)
            .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func brutalistSelectionField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            brutalistFieldLabel(title)
            HStack {
                Text(value)
                    .font(AppTheme.BrutalistTypography.bodyBold)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.vertical, AppTheme.BrutalistSpacing.sm)
            .padding(.horizontal, AppTheme.BrutalistSpacing.md)
            .background(AppTheme.BrutalistPalette.background)
            .overlay(
                Rectangle()
                    .stroke(
                        AppTheme.BrutalistPalette.border,
                        lineWidth: AppTheme.BrutalistBorder.standard
                    )
            )
        }
    }

    private var brutalistQuestionsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            brutalistSectionTitle("Questions")

            if viewModel.questionDrafts.isEmpty {
                Text("Add a question to keep tracking your goal.")
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            } else {
                let lastID = viewModel.questionDrafts.last?.id
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    ForEach($viewModel.questionDrafts) { $draft in
                        brutalistQuestionEditor(for: $draft)

                        if draft.id != lastID {
                            Rectangle()
                                .fill(AppTheme.BrutalistPalette.border.opacity(0.2))
                                .frame(height: 1)
                        }
                    }
                }
            }

            Rectangle()
                .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                .frame(height: 1)

            brutalistNewQuestionComposer
        }
        .brutalistCard()
    }

    private func brutalistQuestionEditor(for draft: Binding<GoalEditorViewModel.QuestionDraft>)
        -> some View
    {
        let draftID = draft.wrappedValue.id

        return VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            HStack(alignment: .center) {
                brutalistFieldLabel("Prompt")
                Spacer()
                Toggle("Active", isOn: draft.isActive)
                    .labelsHidden()
            }

            TextField("Prompt", text: draft.text, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .focused($focusedField, equals: .questionPrompt(draftID))
                .brutalistField(isFocused: focusedField == .questionPrompt(draftID))

            Picker(selection: draft.responseType) {
                ForEach(ResponseType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                brutalistSelectionField(
                    "Response Type",
                    value: draft.wrappedValue.responseType.displayName
                )
            }
            .pickerStyle(.menu)

            brutalistQuestionConfiguration(for: draft)

            HStack {
                Spacer()
                Button(role: .destructive) {
                    Haptics.warning()
                    viewModel.removeDraft(draft.wrappedValue)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .transition(.opacity)
        .onChange(of: draft.responseType.wrappedValue) { _, newType in
            seedDraftDefaults(for: draft, responseType: newType)
        }
    }

    @ViewBuilder
    private func brutalistQuestionConfiguration(
        for draft: Binding<GoalEditorViewModel.QuestionDraft>
    ) -> some View {
        let draftID = draft.wrappedValue.id
        switch draft.responseType.wrappedValue {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                brutalistFieldLabel("Range")
                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        brutalistFieldLabel("Minimum")
                        TextField(
                            "Minimum",
                            value: minimumBinding(
                                for: draft,
                                defaultValue: defaultMinimum(for: draft.responseType.wrappedValue)
                            ),
                            format: .number
                        )
                        .focused($focusedField, equals: .questionMinimum(draftID))
                        .brutalistField(isFocused: focusedField == .questionMinimum(draftID))
                        .platformNumericKeyboard()
                    }

                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        brutalistFieldLabel("Maximum")
                        TextField(
                            "Maximum",
                            value: maximumBinding(
                                for: draft,
                                defaultValue: defaultMaximum(for: draft.responseType.wrappedValue)
                            ),
                            format: .number
                        )
                        .focused($focusedField, equals: .questionMaximum(draftID))
                        .brutalistField(isFocused: focusedField == .questionMaximum(draftID))
                        .platformNumericKeyboard()
                    }
                }

                Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                brutalistFieldLabel("Options")
                Text("Comma separate each choice.")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                TextField("Options", text: optionsBinding(for: draft))
                    .focused($focusedField, equals: .questionOptions(draftID))
                    .brutalistField(isFocused: focusedField == .questionOptions(draftID))
                Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
            }
        case .text, .boolean, .time:
            Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
        }
    }

    private var brutalistNewQuestionComposer: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            brutalistFieldLabel("New Question")

            TextField("Ask a new question", text: $newQuestionText, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .focused($focusedField, equals: .newQuestionPrompt)
                .brutalistField(isFocused: focusedField == .newQuestionPrompt)

            Picker(selection: $newResponseType) {
                ForEach(ResponseType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                brutalistSelectionField("Response Type", value: newResponseType.displayName)
            }
            .pickerStyle(.menu)

            brutalistNewQuestionConfiguration

            Button {
                addQuestion()
            } label: {
                Text("Add Question")
                    .frame(maxWidth: .infinity)
            }
            .brutalistButton(style: .primary)
            .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var brutalistNewQuestionConfiguration: some View {
        switch newResponseType {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                brutalistFieldLabel("Range")
                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        brutalistFieldLabel("Minimum")
                        TextField("Minimum", value: $newQuestionMinimum, format: .number)
                            .focused($focusedField, equals: .newQuestionMinimum)
                            .brutalistField(isFocused: focusedField == .newQuestionMinimum)
                            .platformNumericKeyboard()
                    }

                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        brutalistFieldLabel("Maximum")
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
                brutalistFieldLabel("Options")
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

    private var brutalistScheduleCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            brutalistSectionTitle("Schedule")

            Picker(
                selection: Binding(
                    get: { viewModel.scheduleDraft.frequency },
                    set: { newValue in
                        viewModel.setFrequency(newValue)
                        scheduleError = nil
                        conflictMessage = viewModel.conflictDescription()
                        if conflictMessage != nil {
                            Haptics.warning()
                        } else {
                            Haptics.selection()
                        }
                    }
                )
            ) {
                ForEach(Frequency.allCases, id: \.self) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            } label: {
                brutalistSelectionField(
                    "Frequency",
                    value: viewModel.scheduleDraft.frequency.displayName
                )
            }
            .pickerStyle(.menu)

            switch viewModel.scheduleDraft.frequency {
            case .weekly:
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    WeekdaySelector(
                        selectedWeekdays: Binding(
                            get: { viewModel.scheduleDraft.selectedWeekdays },
                            set: { newValue in
                                viewModel.updateSelectedWeekdays(newValue)
                                scheduleError = nil
                                conflictMessage = viewModel.conflictDescription()
                                if conflictMessage != nil {
                                    Haptics.warning()
                                }
                            }
                        )
                    )

                    if viewModel.scheduleDraft.selectedWeekdays.isEmpty {
                        Text("Select at least one day to send reminders.")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }
            case .custom:
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    brutalistFieldLabel("Interval (days)")
                    IntervalPicker(
                        interval: Binding(
                            get: { viewModel.scheduleDraft.intervalDayCount ?? 3 },
                            set: { newValue in
                                viewModel.updateIntervalDayCount(newValue)
                                scheduleError = nil
                                conflictMessage = viewModel.conflictDescription()
                                if conflictMessage != nil {
                                    Haptics.warning()
                                } else {
                                    Haptics.selection()
                                }
                            }
                        )
                    )
                }
            default:
                EmptyView()
            }

            Picker(
                selection: Binding(
                    get: { viewModel.scheduleDraft.timezone },
                    set: { newTimezone in
                        viewModel.setTimezone(newTimezone)
                        scheduleError = nil
                        conflictMessage = viewModel.conflictDescription()
                        if conflictMessage != nil {
                            Haptics.warning()
                        } else {
                            Haptics.selection()
                        }
                    }
                )
            ) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                    if let timezone = TimeZone(identifier: identifier) {
                        Text(timezoneDisplayName(timezone))
                            .tag(timezone)
                    }
                }
            } label: {
                brutalistSelectionField(
                    "Timezone",
                    value: timeZoneLabel(for: viewModel.scheduleDraft.timezone)
                )
            }
            .pickerStyle(.menu)

            if let conflictMessage {
                ConflictBanner(message: conflictMessage)
            }

            if let scheduleError {
                Text(scheduleError)
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(.red)
            }

            if viewModel.scheduleDraft.times.isEmpty {
                Text("Add at least one reminder time to stay on track.")
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    ForEach(Array(viewModel.scheduleDraft.times.enumerated()), id: \.offset) {
                        index, _ in
                        brutalistReminderRow(index: index)
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
                Text("Add Reminder Time")
                    .frame(maxWidth: .infinity)
            }
            .brutalistButton(style: .secondary)

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                brutalistFieldLabel("New Reminder")
                DatePicker("", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                    .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                    .background(AppTheme.BrutalistPalette.background)
                    .overlay(
                        Rectangle()
                            .stroke(
                                AppTheme.BrutalistPalette.border,
                                lineWidth: AppTheme.BrutalistBorder.standard
                            )
                    )
            }

            Text("Times shown in \(timeZoneLabel(for: viewModel.scheduleDraft.timezone)).")
                .font(AppTheme.BrutalistTypography.caption)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .brutalistCard()
    }

    private func brutalistReminderRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            brutalistFieldLabel("Reminder \(index + 1)")

            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.reminderDate(for: viewModel.scheduleDraft.times[index]) },
                        set: { newValue in
                            if viewModel.updateScheduleTime(at: index, to: newValue) {
                                Haptics.selection()
                                scheduleError = nil
                                conflictMessage = viewModel.conflictDescription()
                            } else {
                                scheduleError = "Reminders must be at least 5 minutes apart."
                                Haptics.warning()
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                .background(AppTheme.BrutalistPalette.background)
                .overlay(
                    Rectangle()
                        .stroke(
                            AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.standard
                        )
                )

                Button(role: .destructive) {
                    viewModel.removeScheduleTime(at: index)
                    scheduleError = nil
                    conflictMessage = viewModel.conflictDescription()
                    Haptics.selection()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(AppTheme.BrutalistPalette.background)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    AppTheme.BrutalistPalette.border,
                                    lineWidth: AppTheme.BrutalistBorder.standard
                                )
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
    }

    private func timeZoneLabel(for timezone: TimeZone) -> String {
        timezone.abbreviation() ?? timezone.identifier
    }

    private func timezoneDisplayName(_ timezone: TimeZone) -> String {
        timezone.localizedName(for: .shortGeneric, locale: .current) ?? timezone.identifier
    }

    var body: some View {
        NavigationStack {
            Group {
                if designStyle == .brutalist {
                    brutalistEditor
                } else {
                    legacyEditor
                }
            }
            .navigationTitle("Edit Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(
                            viewModel.questionDrafts.isEmpty
                                || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty
                        )
                }
            }
            .alert(
                "Unable to Save Goal",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                if !didSeedNewQuestionDefaults {
                    didSeedNewQuestionDefaults = true
                    seedNewQuestionDefaults(for: newResponseType)
                }
                if designStyle == .brutalist, shouldAutoExpandCategories {
                    showAllCategories = true
                }
                conflictMessage = viewModel.conflictDescription()
            }
            .onChange(of: newResponseType) { _, newType in
                seedNewQuestionDefaults(for: newType)
            }
        }
    }

    private var goalDetailsSection: some View {
        Section("Goal Details") {
            TextField("Title", text: $viewModel.title)
                .platformAdaptiveTextField()
                .textContentType(.nickname)
                .font(.title3)

            TextField("Description", text: $viewModel.goalDescription, axis: .vertical)
                .platformAdaptiveTextField()
                .lineLimit(3, reservesSpace: true)

            CategoryPickerView(
                title: "Category",
                primaryOptions: viewModel.primaryCategoryOptions,
                overflowOptions: viewModel.overflowCategoryOptions,
                selectedCategory: editableCategoryBinding,
                customCategoryLabel: $viewModel.customCategoryLabel,
                onSelectOption: { option in
                    viewModel.selectCategory(option)
                },
                onUpdateCustomLabel: { label in
                    viewModel.updateCustomCategoryLabel(label)
                }
            )
        }
    }

    private var questionsSection: some View {
        Section("Questions") {
            if viewModel.questionDrafts.isEmpty {
                ContentUnavailableView(
                    "Add a question to keep tracking", systemImage: "text.badge.plus")
            } else {
                ForEach($viewModel.questionDrafts) { $draft in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Prompt", text: $draft.text)
                        Picker("Response", selection: $draft.responseType) {
                            ForEach(ResponseType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Active", isOn: $draft.isActive)
                        configurationFields(for: $draft)
                    }
                    .onChange(of: draft.responseType) { _, newType in
                        seedDraftDefaults(for: $draft, responseType: newType)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Haptics.warning()
                            viewModel.removeDraft(draft)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Ask a new question", text: $newQuestionText)
                    .platformAdaptiveTextField()
                Picker("Response Type", selection: $newResponseType) {
                    ForEach(ResponseType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                newQuestionConfigurationFields
                Button {
                    addQuestion()
                } label: {
                    Label("Add Question", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func configurationFields(for draft: Binding<GoalEditorViewModel.QuestionDraft>)
        -> some View
    {
        switch draft.responseType.wrappedValue {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "Minimum",
                            value: minimumBinding(
                                for: draft,
                                defaultValue: defaultMinimum(for: draft.responseType.wrappedValue)),
                            format: .number
                        )
                        .platformNumericKeyboard()
                        .platformTextField()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "Maximum",
                            value: maximumBinding(
                                for: draft,
                                defaultValue: defaultMaximum(for: draft.responseType.wrappedValue)),
                            format: .number
                        )
                        .platformNumericKeyboard()
                        .platformTextField()
                    }
                }
                Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Options (comma separated)", text: optionsBinding(for: draft))
                Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
            }
        case .text:
            Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
        case .boolean, .time:
            Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
        }
    }

    private func minimumBinding(
        for draft: Binding<GoalEditorViewModel.QuestionDraft>, defaultValue: Double
    ) -> Binding<Double> {
        Binding<Double>(
            get: { draft.validationRules.wrappedValue?.minimumValue ?? defaultValue },
            set: { newValue in
                var rules =
                    draft.validationRules.wrappedValue
                    ?? ValidationRules(
                        allowsEmpty: draft.validationRules.wrappedValue?.allowsEmpty ?? false)
                rules.minimumValue = newValue
                if let maximum = rules.maximumValue, maximum < newValue {
                    rules.maximumValue = newValue
                }
                draft.validationRules.wrappedValue = rules
            }
        )
    }

    private func maximumBinding(
        for draft: Binding<GoalEditorViewModel.QuestionDraft>, defaultValue: Double
    ) -> Binding<Double> {
        Binding<Double>(
            get: { draft.validationRules.wrappedValue?.maximumValue ?? defaultValue },
            set: { newValue in
                var rules =
                    draft.validationRules.wrappedValue
                    ?? ValidationRules(
                        allowsEmpty: draft.validationRules.wrappedValue?.allowsEmpty ?? false)
                let minimum = rules.minimumValue ?? defaultValue
                rules.maximumValue = max(newValue, minimum)
                draft.validationRules.wrappedValue = rules
            }
        )
    }

    private func allowsEmptyBinding(for draft: Binding<GoalEditorViewModel.QuestionDraft>)
        -> Binding<Bool>
    {
        Binding<Bool>(
            get: { draft.validationRules.wrappedValue?.allowsEmpty ?? false },
            set: { newValue in
                var rules =
                    draft.validationRules.wrappedValue ?? ValidationRules(allowsEmpty: newValue)
                rules.allowsEmpty = newValue
                draft.validationRules.wrappedValue = rules
            }
        )
    }

    @ViewBuilder
    private var newQuestionConfigurationFields: some View {
        switch newResponseType {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Minimum", value: $newQuestionMinimum, format: .number)
                            .platformNumericKeyboard()
                            .platformTextField()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Maximum", value: $newQuestionMaximum, format: .number)
                            .platformNumericKeyboard()
                            .platformTextField()
                    }
                }
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Options (comma separated)", text: $newQuestionOptionsText)
                    .platformAdaptiveTextField()
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .text:
            Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
        case .boolean, .time:
            Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
        }
    }

    private func optionsBinding(for draft: Binding<GoalEditorViewModel.QuestionDraft>) -> Binding<
        String
    > {
        Binding<String>(
            get: { draft.options.wrappedValue.joined(separator: ", ") },
            set: { newValue in
                draft.options.wrappedValue = parseOptions(from: newValue)
            }
        )
    }

    private func defaultMinimum(for responseType: ResponseType) -> Double {
        switch responseType {
        case .scale:
            return 1
        case .waterIntake:
            return 0
        default:
            return 0
        }
    }

    private func defaultMaximum(for responseType: ResponseType) -> Double {
        switch responseType {
        case .scale:
            return 10
        case .waterIntake:
            return 128
        default:
            return 100
        }
    }

    private func seedDraftDefaults(
        for draft: Binding<GoalEditorViewModel.QuestionDraft>, responseType: ResponseType
    ) {
        let allowsEmpty = draft.validationRules.wrappedValue?.allowsEmpty ?? false
        switch responseType {
        case .numeric:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(
                minimumValue: 0, maximumValue: 100, allowsEmpty: allowsEmpty)
        case .scale:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(
                minimumValue: 1, maximumValue: 10, allowsEmpty: allowsEmpty)
        case .slider:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(
                minimumValue: 0, maximumValue: 100, allowsEmpty: allowsEmpty)
        case .waterIntake:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(
                minimumValue: 0, maximumValue: 128, allowsEmpty: allowsEmpty)
        case .multipleChoice:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(allowsEmpty: allowsEmpty)
        case .text:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(allowsEmpty: allowsEmpty)
        case .boolean, .time:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue =
                allowsEmpty ? ValidationRules(allowsEmpty: true) : nil
        }
    }

    private func parseOptions(from text: String) -> [String] {
        let candidates =
            text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        var seen: Set<String> = []
        for item in candidates where !seen.contains(item.lowercased()) {
            seen.insert(item.lowercased())
            unique.append(item)
        }
        return unique
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker(
                "Frequency",
                selection: Binding(
                    get: { viewModel.scheduleDraft.frequency },
                    set: { newValue in
                        viewModel.setFrequency(newValue)
                        scheduleError = nil
                        let conflict = viewModel.conflictDescription()
                        conflictMessage = conflict
                        if conflict != nil {
                            Haptics.warning()
                        } else {
                            Haptics.selection()
                        }
                    }
                )
            ) {
                ForEach(Frequency.allCases, id: \.self) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }

            switch viewModel.scheduleDraft.frequency {
            case .weekly:
                WeekdaySelector(
                    selectedWeekdays: Binding(
                        get: { viewModel.scheduleDraft.selectedWeekdays },
                        set: { newValue in
                            viewModel.updateSelectedWeekdays(newValue)
                            scheduleError = nil
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            }
                        }
                    )
                )
                .padding(.vertical, 4)
                if viewModel.scheduleDraft.selectedWeekdays.isEmpty {
                    Text("Select at least one day to send reminders.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .custom:
                IntervalPicker(
                    interval: Binding(
                        get: { viewModel.scheduleDraft.intervalDayCount ?? 3 },
                        set: { newValue in
                            viewModel.updateIntervalDayCount(newValue)
                            scheduleError = nil
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                        }
                    )
                )
            default:
                EmptyView()
            }

            Picker(
                "Timezone",
                selection: Binding(
                    get: { viewModel.scheduleDraft.timezone },
                    set: {
                        viewModel.setTimezone($0)
                        scheduleError = nil
                        let conflict = viewModel.conflictDescription()
                        conflictMessage = conflict
                        if conflict != nil {
                            Haptics.warning()
                        } else {
                            Haptics.selection()
                        }
                    }
                )
            ) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                    if let timezone = TimeZone(identifier: identifier) {
                        Text(
                            timezone.localizedName(for: .shortGeneric, locale: .current)
                                ?? identifier
                        )
                        .tag(timezone)
                    }
                }
            }

            if let conflictMessage {
                Text(conflictMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let scheduleError {
                Text(scheduleError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if viewModel.scheduleDraft.times.isEmpty {
                ContentUnavailableView("Add at least one reminder", systemImage: "alarm")
            } else {
                ForEach(Array(viewModel.scheduleDraft.times.enumerated()), id: \.offset) {
                    index, scheduleTime in
                    HStack {
                        DatePicker(
                            "Reminder \(index + 1)",
                            selection: Binding(
                                get: { viewModel.reminderDate(for: scheduleTime) },
                                set: { newValue in
                                    if viewModel.updateScheduleTime(at: index, to: newValue) {
                                        Haptics.selection()
                                        scheduleError = nil
                                        conflictMessage = viewModel.conflictDescription()
                                    } else {
                                        scheduleError =
                                            "Reminders must be at least 5 minutes apart."
                                        Haptics.warning()
                                    }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        Button(role: .destructive) {
                            viewModel.removeScheduleTime(at: index)
                            scheduleError = nil
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
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
                Label("Add Reminder Time", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            DatePicker(
                "New Reminder", selection: $newReminderTime, displayedComponents: .hourAndMinute)
        }
    }

    private func seedNewQuestionDefaults(for responseType: ResponseType) {
        newQuestionAllowsEmpty = false
        newQuestionOptionsText = ""
        switch responseType {
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
        case .multipleChoice:
            break
        case .text, .boolean, .time:
            break
        }
    }

    private func resetNewQuestionFields() {
        newQuestionText = ""
        newResponseType = .numeric
        seedNewQuestionDefaults(for: .numeric)
    }

    private func addQuestion() {
        let trimmed = newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var options: [String]? = nil
        var validation: ValidationRules? = nil

        switch newResponseType {
        case .multipleChoice:
            let parsed = parseOptions(from: newQuestionOptionsText)
            if parsed.isEmpty {
                errorMessage = "Add at least one option before saving."
                Haptics.warning()
                return
            }
            options = parsed
            validation = ValidationRules(allowsEmpty: newQuestionAllowsEmpty)
        case .numeric, .scale, .slider, .waterIntake:
            let minimum = min(newQuestionMinimum, newQuestionMaximum)
            let maximum = max(newQuestionMinimum, newQuestionMaximum)
            validation = ValidationRules(
                minimumValue: minimum, maximumValue: maximum, allowsEmpty: newQuestionAllowsEmpty)
        case .text, .boolean, .time:
            if newQuestionAllowsEmpty {
                validation = ValidationRules(allowsEmpty: true)
            }
        }

        viewModel.addQuestion(
            text: trimmed,
            responseType: newResponseType,
            options: options,
            validationRules: validation
        )

        Haptics.selection()
        resetNewQuestionFields()
    }

    private func handleSave() {
        do {
            let goal = try viewModel.saveChanges()
            Haptics.success()
            NotificationScheduler.shared.scheduleNotifications(for: goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

extension GoalEditView {
    fileprivate var editableCategoryBinding: Binding<TrackingCategory?> {
        Binding<TrackingCategory?>(
            get: { viewModel.selectedCategory },
            set: { newValue in
                if let category = newValue {
                    viewModel.selectedCategory = category
                }
            }
        )
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
            let goal = goals.first
        {
            let viewModel = GoalEditorViewModel(goal: goal, modelContext: context)
            GoalEditView(viewModel: viewModel)
                .modelContainer(container)
        } else {
            Text("No Sample Goal")
        }
    } else {
        Text("Preview Error Loading Sample Data")
    }
}

// MARK: - Platform-specific View Extensions
extension View {
    @ViewBuilder
    fileprivate func platformNumericKeyboard() -> some View {
        #if os(iOS)
            self.keyboardType(.decimalPad)
        #else
            self
        #endif
    }

    @ViewBuilder
    fileprivate func platformTextField() -> some View {
        #if os(iOS)
            self.textFieldStyle(.roundedBorder)
        #else
            self.textFieldStyle(.plain)
        #endif
    }
}
