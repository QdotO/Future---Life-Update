import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if DEBUG
    struct NotificationInspectorView: View {
        @Environment(\.modelContext) private var modelContext
        @State private var viewModel: NotificationInspectorViewModel?
        @State private var showingExportSheet = false
        @State private var exportDocument = NotificationReportDocument()

        var body: some View {
            Group {
                if let viewModel = viewModel {
                    inspectorContent(viewModel: viewModel)
                } else {
                    ProgressView("Loading...")
                        .task {
                            initializeViewModel()
                        }
                }
            }
            .navigationTitle("Notification Inspector")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .fileExporter(
                isPresented: $showingExportSheet,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "notification-report-\(Date().ISO8601Format()).json"
            ) { _ in }
        }

        @ViewBuilder
        private func inspectorContent(viewModel: NotificationInspectorViewModel) -> some View {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Groups")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.groupedNotifications.count)")
                                .font(.title2.bold())
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Last Refresh")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lastRefresh = viewModel.lastRefresh {
                                Text(lastRefresh, style: .relative)
                                    .font(.caption)
                            } else {
                                Text("Never")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Button {
                            Task {
                                await viewModel.refresh()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)

                        Spacer()

                        Button(role: .destructive) {
                            viewModel.purgeAllStaleNotifications()
                        } label: {
                            Label("Purge Stale", systemImage: "trash")
                        }
                        .disabled(
                            viewModel.groupedNotifications.filter {
                                $0.goalStatus == .missing || $0.goalStatus == .inactive
                            }.isEmpty)

                        Spacer()

                        Button {
                            if let data = viewModel.exportReport() {
                                exportDocument = NotificationReportDocument(data: data)
                                showingExportSheet = true
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                } header: {
                    Text("Overview")
                }

                if viewModel.groupedNotifications.isEmpty {
                    ContentUnavailableView(
                        "No Notifications",
                        systemImage: "bell.slash",
                        description: Text("There are no scheduled or delivered notifications.")
                    )
                } else {
                    ForEach(viewModel.groupedNotifications) { group in
                        Section {
                            ForEach(group.notifications) { notification in
                                NotificationRow(notification: notification)
                            }
                        } header: {
                            HStack {
                                Label(
                                    group.goalTitle ?? "Unknown Goal",
                                    systemImage: group.goalStatus.symbolName)
                                Spacer()
                                Text(group.goalStatus.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } footer: {
                            HStack {
                                Button {
                                    viewModel.cancelNotifications(for: group)
                                } label: {
                                    Label("Cancel All", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                if group.goalStatus != .missing {
                                    Button {
                                        viewModel.rescheduleGoal(group)
                                    } label: {
                                        Label("Reschedule", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }

        private func initializeViewModel() {
            let vm = NotificationInspectorViewModel(modelContext: modelContext)
            viewModel = vm
            Task {
                await vm.refresh()
            }
        }
    }

    private struct NotificationRow: View {
        let notification: NotificationInspectorViewModel.NotificationDetail

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                    Spacer()
                    if notification.isDelivered {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    if let fireDate = notification.nextFireDate {
                        Text(fireDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text("No fire date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(notification.triggerDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private struct NotificationReportDocument: FileDocument {
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

    #Preview {
        if let container = try? PreviewSampleData.makePreviewContainer() {
            NavigationStack {
                NotificationInspectorView()
            }
            .modelContainer(container)
        } else {
            Text("Preview Error")
        }
    }
#endif
