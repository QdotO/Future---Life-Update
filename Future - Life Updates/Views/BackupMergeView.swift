import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupMergeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var primaryFileURL: URL?
    @State private var secondaryFileURL: URL?
    @State private var isPresentingPrimaryPicker = false
    @State private var isPresentingSecondaryPicker = false
    @State private var mergeResult: BackupMergeService.MergeResult?
    @State private var isProcessing = false
    @State private var alertInfo: MergeAlert?
    @State private var showingConflictReport = false
    @State private var showingMergedExporter = false
    @State private var showingConflictExporter = false
    @State private var mergedDocument = BackupDocument()
    @State private var conflictDocument = ConflictReportDocument()

    var body: some View {
        Form {
            Section {
                Text(
                    "Select two backup files to merge them into a single backup. Conflicts will be detected and reported."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section("Primary Backup") {
                if let url = primaryFileURL {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text(url.lastPathComponent)
                        Spacer()
                        Button("Change") {
                            isPresentingPrimaryPicker = true
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        isPresentingPrimaryPicker = true
                    } label: {
                        Label("Select Primary File", systemImage: "doc.badge.plus")
                    }
                }
            }

            Section("Secondary Backup") {
                if let url = secondaryFileURL {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text(url.lastPathComponent)
                        Spacer()
                        Button("Change") {
                            isPresentingSecondaryPicker = true
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        isPresentingSecondaryPicker = true
                    } label: {
                        Label("Select Secondary File", systemImage: "doc.badge.plus")
                    }
                }
            }

            if let result = mergeResult {
                Section("Merge Result") {
                    if result.hasConflicts, let report = result.conflicts {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                "Conflicts Detected", systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(.orange)

                            Text("\(report.summary.totalConflicts) conflicts found")
                                .font(.subheadline)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Goal conflicts:")
                                    Text("Question conflicts:")
                                    Text("Data point conflicts:")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(report.summary.goalConflicts)")
                                    Text("\(report.summary.questionConflicts)")
                                    Text("\(report.summary.dataPointConflicts)")
                                }
                                .font(.caption.bold())
                            }

                            Button {
                                showingConflictReport = true
                            } label: {
                                Label(
                                    "View Conflict Details", systemImage: "doc.text.magnifyingglass"
                                )
                            }
                            .buttonStyle(.bordered)

                            Button {
                                exportConflictReport(report)
                            } label: {
                                Label("Export Conflict Report", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)

                        if report.summary.canProceedWithoutConflictingData {
                            Button(role: .destructive) {
                                proceedWithoutConflicts()
                            } label: {
                                Label(
                                    "Proceed Without Conflicting Data",
                                    systemImage: "exclamationmark.triangle")
                            }
                        }
                    } else if result.success, let merged = result.merged {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Merge Successful", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)

                            Text("\(merged.goals.count) goals merged")
                                .font(.subheadline)

                            HStack {
                                Button {
                                    exportMergedBackup(merged)
                                } label: {
                                    Label("Export Merged File", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    importMerged(merged)
                                } label: {
                                    Label("Import Now", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button {
                    performMerge()
                } label: {
                    Label("Merge Backups", systemImage: "arrow.triangle.merge")
                }
                .disabled(primaryFileURL == nil || secondaryFileURL == nil || isProcessing)
            }
        }
        .navigationTitle("Merge Backups")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .fileImporter(
            isPresented: $isPresentingPrimaryPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, isPrimary: true)
        }
        .fileImporter(
            isPresented: $isPresentingSecondaryPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, isPrimary: false)
        }
        .fileExporter(
            isPresented: $showingMergedExporter,
            document: mergedDocument,
            contentType: .json,
            defaultFilename: "merged-backup-\(Date().ISO8601Format()).json"
        ) { result in
            if case .failure(let error) = result {
                alertInfo = MergeAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .fileExporter(
            isPresented: $showingConflictExporter,
            document: conflictDocument,
            contentType: .json,
            defaultFilename: "merge-conflict-report-\(Date().ISO8601Format()).json"
        ) { result in
            if case .failure(let error) = result {
                alertInfo = MergeAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingConflictReport) {
            if let conflicts = mergeResult?.conflicts {
                ConflictReportView(report: conflicts)
            }
        }
        .alert(item: $alertInfo) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func handleFileSelection(result: Result<[URL], Error>, isPrimary: Bool) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if isPrimary {
                primaryFileURL = url
            } else {
                secondaryFileURL = url
            }
            // Clear previous merge result when files change
            mergeResult = nil
        case .failure(let error):
            alertInfo = MergeAlert(
                title: "File Selection Failed", message: error.localizedDescription)
        }
    }

    private func performMerge() {
        guard let primaryURL = primaryFileURL,
            let secondaryURL = secondaryFileURL
        else { return }

        isProcessing = true

        Task {
            do {
                // Load both files
                let primaryData = try accessData(at: primaryURL)
                let secondaryData = try accessData(at: secondaryURL)

                // Decode payloads
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let primaryPayload = try decoder.decode(BackupPayload.self, from: primaryData)
                let secondaryPayload = try decoder.decode(BackupPayload.self, from: secondaryData)

                // Perform merge
                let mergeService = BackupMergeService()
                let result = mergeService.mergeBackups(
                    primary: primaryPayload,
                    secondary: secondaryPayload,
                    strategy: .stopOnConflict
                )

                await MainActor.run {
                    mergeResult = result
                    isProcessing = false

                    if result.hasConflicts {
                        alertInfo = MergeAlert(
                            title: "Conflicts Detected",
                            message:
                                "The merge found \(result.conflicts?.summary.totalConflicts ?? 0) conflicts. Review them before proceeding."
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    alertInfo = MergeAlert(
                        title: "Merge Failed", message: error.localizedDescription)
                    isProcessing = false
                }
            }
        }
    }

    private func proceedWithoutConflicts() {
        guard let primaryURL = primaryFileURL,
            let secondaryURL = secondaryFileURL
        else { return }

        isProcessing = true

        Task {
            do {
                // Load both files
                let primaryData = try accessData(at: primaryURL)
                let secondaryData = try accessData(at: secondaryURL)

                // Decode payloads
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let primaryPayload = try decoder.decode(BackupPayload.self, from: primaryData)
                let secondaryPayload = try decoder.decode(BackupPayload.self, from: secondaryData)

                // Perform merge with skip strategy
                let mergeService = BackupMergeService()
                let result = mergeService.mergeBackups(
                    primary: primaryPayload,
                    secondary: secondaryPayload,
                    strategy: .skipConflicting
                )

                await MainActor.run {
                    mergeResult = result
                    isProcessing = false

                    if result.success {
                        alertInfo = MergeAlert(
                            title: "Merge Complete",
                            message:
                                "Conflicting data was skipped. The merge is ready to export or import."
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    alertInfo = MergeAlert(
                        title: "Merge Failed", message: error.localizedDescription)
                    isProcessing = false
                }
            }
        }
    }

    private func exportMergedBackup(_ payload: BackupPayload) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            mergedDocument = BackupDocument(data: data)
            showingMergedExporter = true
        } catch {
            alertInfo = MergeAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func exportConflictReport(_ report: BackupMergeService.MergeConflictReport) {
        do {
            let service = BackupMergeService()
            let data = try service.exportConflictReport(report)
            conflictDocument = ConflictReportDocument(data: data)
            showingConflictExporter = true
        } catch {
            alertInfo = MergeAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func importMerged(_ payload: BackupPayload) {
        isProcessing = true

        Task {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(payload)

                await MainActor.run {
                    let backupManager = DataBackupManager(modelContext: modelContext)
                    do {
                        let summary = try backupManager.importBackup(
                            from: data, replaceExisting: true)
                        alertInfo = MergeAlert(
                            title: "Import Complete",
                            message:
                                "Restored \(summary.goalsImported) goals and \(summary.dataPointsImported) entries."
                        )
                    } catch {
                        alertInfo = MergeAlert(
                            title: "Import Failed", message: error.localizedDescription)
                    }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    alertInfo = MergeAlert(
                        title: "Import Failed", message: error.localizedDescription)
                    isProcessing = false
                }
            }
        }
    }

    private func accessData(at url: URL) throws -> Data {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}

private struct ConflictReportView: View {
    let report: BackupMergeService.MergeConflictReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Total Conflicts", value: "\(report.summary.totalConflicts)")
                    LabeledContent("Goal Conflicts", value: "\(report.summary.goalConflicts)")
                    LabeledContent(
                        "Question Conflicts", value: "\(report.summary.questionConflicts)")
                    LabeledContent(
                        "Data Point Conflicts", value: "\(report.summary.dataPointConflicts)")
                }

                ForEach(report.conflicts, id: \.goalID) { conflict in
                    Section(conflict.goalTitle) {
                        LabeledContent("Type", value: conflict.type.rawValue)
                        LabeledContent("Field", value: conflict.field)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primary Value:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(conflict.primaryValue)
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secondary Value:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(conflict.secondaryValue)
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommendation:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(conflict.recommendation)
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Conflict Report")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ConflictReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct MergeAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        BackupMergeView()
    }
    .modelContainer(for: TrackingGoal.self, inMemory: true)
}
