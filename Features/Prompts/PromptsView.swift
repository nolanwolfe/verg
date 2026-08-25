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
    ///
    /// Written only by "Select Guidance". Drawing used to write here
    /// directly, which meant every shuffle was already committed and there
    /// was no point at which you chose — you could only stop drawing. The
    /// draw now moves `draft`, and nothing reaches the session until the
    /// button is pressed.
    @Binding var selection: WritingPrompt?

    /// What is on screen, which is not yet what you have chosen.
    @State private var draft: WritingPrompt?
    @State private var showLibrary = false
    /// Nudges the card as it changes, so a swipe reads as dealing a card
    /// rather than the text silently replacing itself.
    @State private var cardOffset: CGFloat = 0

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()

                    Text(draft?.text ?? "Writing without a script.")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .offset(x: cardOffset)
                        .accessibilityIdentifier("oracle.script")
                        // Swipe to deal the next one. Horizontal only, and
                        // only past a real threshold — the sheet itself is
                        // dismissed by a downward drag, and a lazy diagonal
                        // shouldn't do both.
                        .gesture(
                            DragGesture(minimumDistance: 24)
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height),
                                          abs(value.translation.width) > 48 else { return }
                                    shuffle()
                                }
                        )
                        .animation(Theme.Animation.quick, value: draft?.id)

                    Spacer()

                    VStack(spacing: Theme.Spacing.sm) {
                        // The only thing that writes to `selection`. Until
                        // this is pressed the sheet is a shuffle you can walk
                        // away from.
                        Button {
                            AudioService.shared.playUITick()
                            selection = draft
                            dismiss()
                        } label: {
                            Text("Select Guidance")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(draft == nil)
                        .accessibilityIdentifier("oracle.select")

                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                shuffle()
                            } label: {
                                secondaryLabel("Draw another")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("oracle.draw")

                            Button {
                                showLibrary = true
                            } label: {
                                secondaryLabel("Your scripts")
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            AudioService.shared.playUITick()
                            selection = nil
                            dismiss()
                        } label: {
                            Text("No script")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: Theme.Layout.buttonHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("oracle.none")
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .navigationTitle("The Oracle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel, not Done: leaving without pressing Select
                // Guidance must leave the session's script as it was, or
                // the confirm step is decorative.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .sheet(isPresented: $showLibrary) {
                PromptLibraryView()
                    .environmentObject(storageService)
            }
            // Resume from whatever the session already has, so reopening
            // shows your current script rather than a blank card.
            //
            // Deliberately no auto-draw: arriving with no script is a real
            // state the user chose, and silently picking one would undo
            // "No script" every time this opened. Select Guidance stays
            // disabled until something has actually been drawn.
            .onAppear { draft = selection }
        }
        // Half screen, like every other picker in the app. This is one card
        // and four controls; presented full-height it was mostly empty, and
        // it read as a screen rather than a choice. Draggable up for long
        // scripts and large text sizes.
        .presentationDetents([.medium, .large])
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
        withAnimation(.easeIn(duration: 0.10)) { cardOffset = -18 }
        draft = WritingPrompt.next(from: storageService.allPrompts, after: draft)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { cardOffset = 0 }
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
        // Sized to what is in it. A handful of scripts in a full-height
        // sheet is mostly blank paper; a long collection in a half sheet is
        // a scroll through a letterbox. Both detents stay available either
        // way — the count only decides which one it opens at.
        .presentationDetents(isLongCollection ? [.large] : [.medium, .large])
    }

    /// Enough rows that a half sheet would be scrolled immediately. Folders
    /// count: each is a row before any of its scripts are.
    private var isLongCollection: Bool {
        storageService.customPrompts.count + storageService.promptFolders.count > 6
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
