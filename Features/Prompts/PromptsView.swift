import SwiftUI

// MARK: - Oracle
/// One script at a time, and two ways forward: draw another, or open your
/// own collection. Deliberately not a scrolling list — a wall of scripts is
/// a decision, and the point is to remove one.
struct PromptSheetView: View {
    @EnvironmentObject private var storageService: StorageService
    @Environment(\.dismiss) private var dismiss

    /// The prompt currently shown on the Home pill, so reopening the sheet
    /// resumes where it left off instead of jumping.
    @Binding var selection: WritingPrompt?

    @State private var showLibrary = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()

                    Text(selection?.text ?? "Writing without a script.")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .animation(Theme.Animation.quick, value: selection?.id)

                    Spacer()

                    VStack(spacing: Theme.Spacing.sm) {
                        Button {
                            shuffle()
                        } label: {
                            Text("Draw another")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                showLibrary = true
                            } label: {
                                secondaryLabel("Your scripts")
                            }
                            .buttonStyle(.plain)

                            Button {
                                AudioService.shared.playUITick()
                                selection = nil
                                dismiss()
                            } label: {
                                secondaryLabel("No script")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .navigationTitle("The Oracle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .sheet(isPresented: $showLibrary) {
                PromptLibraryView()
                    .environmentObject(storageService)
            }
            // Deliberately no auto-draw on appear: arriving with no script
            // is a real state the user can choose, and silently picking one
            // would undo "No script" every time this opened.
        }
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
    }

    private func shuffle() {
        AudioService.shared.playUITick()
        selection = WritingPrompt.next(from: storageService.allPrompts, after: selection)
    }
}

// MARK: - Prompt Library
/// The user's own scripts, in folders. The built-in set isn't listed — it's
/// fixed and always in the draw; this screen is only what you added.
struct PromptLibraryView: View {
    @EnvironmentObject private var storageService: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var showAddPrompt = false
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    /// The script being edited. Presented with `item:` so the row that was
    /// tapped travels with the sheet.
    @State private var editingPrompt: WritingPrompt?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if storageService.customPrompts.isEmpty && storageService.promptFolders.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(storageService.promptFolders) { folder in
                            Section {
                                folderRows(for: folder)
                            } header: {
                                Text(folder.name)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }

                        let loose = storageService.prompts(inFolder: nil)
                        if !loose.isEmpty {
                            Section {
                                ForEach(loose) { prompt in
                                    promptRow(prompt)
                                }
                            } header: {
                                Text(storageService.promptFolders.isEmpty ? "YOUR SCRIPTS" : "NO FOLDER")
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Your scripts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddPrompt = true
                        } label: {
                            Label("New script", systemImage: "plus")
                        }
                        Button {
                            newFolderName = ""
                            showAddFolder = true
                        } label: {
                            Label("New folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddPrompt) {
                PromptEditorView()
                    .environmentObject(storageService)
            }
            .sheet(item: $editingPrompt) { prompt in
                PromptEditorView(editing: prompt)
                    .environmentObject(storageService)
            }
            .alert("New folder", isPresented: $showAddFolder) {
                TextField("Name", text: $newFolderName)
                Button("Create") { storageService.addPromptFolder(newFolderName) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    @ViewBuilder
    private func folderRows(for folder: PromptFolder) -> some View {
        let prompts = storageService.prompts(inFolder: folder.id)
        if prompts.isEmpty {
            Text("Empty")
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.6))
                .listRowBackground(Theme.Colors.cardBackground)
        } else {
            ForEach(prompts) { prompt in
                promptRow(prompt)
            }
        }

        Button(role: .destructive) {
            storageService.deletePromptFolder(id: folder.id)
        } label: {
            // Says what it does: the prompts inside survive the folder.
            Text("Delete folder — keeps its scripts")
                .font(Theme.Typography.footnote)
        }
        .listRowBackground(Theme.Colors.cardBackground)
    }

    private func promptRow(_ prompt: WritingPrompt) -> some View {
        // Tapping opens the editor. There was previously no way at all to
        // change a script once written — only delete it and start again.
        Button {
            editingPrompt = prompt
        } label: {
            HStack {
                Text(prompt.text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
            .listRowBackground(Theme.Colors.cardBackground)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    storageService.deleteCustomPrompt(id: prompt.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button {
                    editingPrompt = prompt
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Menu("Move to") {
                    Button("No folder") {
                        storageService.moveCustomPrompt(id: prompt.id, toFolder: nil)
                    }
                    ForEach(storageService.promptFolders) { folder in
                        Button(folder.name) {
                            storageService.moveCustomPrompt(id: prompt.id, toFolder: folder.id)
                        }
                    }
                }
                Button(role: .destructive) {
                    storageService.deleteCustomPrompt(id: prompt.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "text.quote")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))

            Text("Nothing here yet.")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.primaryText)

            Text("Add your own scripts and sort them into folders.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

// MARK: - Prompt Editor
struct PromptEditorView: View {
    /// The script being changed, or nil when writing a new one. One screen
    /// for both — the fields, the folder picker and the validation are
    /// identical, and only the title and what Save does differ.
    var editing: WritingPrompt?

    @EnvironmentObject private var storageService: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var folderID: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("SCRIPT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)

                        TextField("Something to write toward", text: $text, axis: .vertical)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .lineLimit(3, reservesSpace: true)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if !storageService.promptFolders.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("FOLDER")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.secondaryText)

                            Picker("Folder", selection: $folderID) {
                                Text("No folder").tag(UUID?.none)
                                ForEach(storageService.promptFolders) { folder in
                                    Text(folder.name).tag(UUID?.some(folder.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.Colors.accent)
                        }
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .onAppear {
                guard let editing else { return }
                text = editing.text
                folderID = editing.folderID
            }
            .navigationTitle(editing == nil ? "New script" : "Edit script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let editing {
                            storageService.updateCustomPrompt(id: editing.id, text: text)
                            storageService.moveCustomPrompt(id: editing.id, toFolder: folderID)
                        } else {
                            storageService.addCustomPrompt(text, folderID: folderID)
                        }
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PromptSheetView(selection: .constant(WritingPrompt.builtIn.first))
        .environmentObject(StorageService.shared)
}
