import SwiftUI

// MARK: - Oracle
/// One script at a time. Tap or swipe the card to draw the next; Select
/// Guidance commits the one showing. Deliberately not a scrolling list — a
/// wall of scripts is a decision, and the point is to remove one.
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
    /// Bumped on every draw so the card can be re-identified, which is what
    /// drives the deal transition. Not an offset animated by hand: setting
    /// one and unsetting it in the same pass raced the implicit animation on
    /// the text and made a single tap look like two switches.
    @State private var drawCount: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()

                    Text(draft?.text ?? "The oracle is silent. Tap to ask.")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .accessibilityIdentifier("oracle.script")
                        // One identity per draw, one transition per identity.
                        .id(drawCount)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        // Swipe to deal the next one. Horizontal only, and
                        // only past a real threshold — the sheet itself is
                        // dismissed by a downward drag, and a lazy diagonal
                        // shouldn't do both.
                        .contentShape(Rectangle())
                        .onTapGesture { shuffle() }
                        .gesture(
                            DragGesture(minimumDistance: 24)
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height),
                                          abs(value.translation.width) > 48 else { return }
                                    shuffle()
                                }
                        )

                    Spacer()

                    VStack(spacing: Theme.Spacing.sm) {
                        // The only thing that writes to `selection`: until
                        // it is pressed the sheet is a shuffle you can walk
                        // away from. Never inert. With nothing drawn it draws — which
                        // is what a person pressing the only lit button on
                        // the screen means — and once a script is up it
                        // commits that one. Disabling it instead made the
                        // sheet look broken on the first open, which is the
                        // glitch this replaces.
                        Button {
                            // Commits what is showing — always, and only.
                            // It briefly drew when nothing was up, which
                            // meant the confirm button sometimes dealt a
                            // card instead of accepting one. With no script
                            // drawn, what is showing *is* "no script", so
                            // that is what it commits.
                            AudioService.shared.playUITick()
                            selection = draft
                            dismiss()
                        } label: {
                            Text("Write this one")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("oracle.select")

                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                AudioService.shared.playUITick()
                                showLibrary = true
                            } label: {
                                secondaryLabel("Your questions")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("oracle.mine")

                            Button {
                                AudioService.shared.playUITick()
                                selection = nil
                                dismiss()
                            } label: {
                                secondaryLabel("No question")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("oracle.none")
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .navigationTitle("The Oracle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Done, not Cancel: the word says you're leaving, and the
                // behaviour is unchanged — nothing is committed unless
                // "Write this one" is pressed. The old comment's rule holds:
                // backing out must leave the session's question as it was.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .sheet(isPresented: $showLibrary) {
                // Chosen, not committed: one of your own scripts lands in
                // the same draft a drawn one does, and Select Guidance is
                // still what accepts it.
                PromptLibraryView(onSelect: { picked in
                    draft = picked
                })
                .environmentObject(storageService)
            }
            // Resume from whatever the session already has, so reopening
            // shows your current script rather than a blank card.
            //
            // Deliberately no auto-draw: arriving with no script is a real
            // state the user chose, and silently picking one would undo
            // "No script" every time this opened. The card says so and
            // invites the tap instead.
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
        AudioService.shared.playOracleDraw()
        // One animation, one state change. The card leaves left and the next
        // arrives from the right — a deal, not a redraw.
        withAnimation(.easeInOut(duration: 0.26)) {
            draft = WritingPrompt.next(from: storageService.allPrompts, after: draft)
            drawCount += 1
        }
    }
}

// MARK: - Prompt Library
/// The user's own scripts, in folders. The built-in set isn't listed — it's
/// fixed and always in the draw; this screen is only what you added.
struct PromptLibraryView: View {
    @EnvironmentObject private var storageService: StorageService
    @Environment(\.dismiss) private var dismiss

    /// Set when this list is being used to *choose* a script — from the
    /// Oracle. Nil when it is being browsed from Settings, where there is no
    /// session to choose into and a tap can only mean edit.
    ///
    /// Without this the whole row opened the editor, so picking one of your
    /// own scripts was impossible: every attempt to select put you in
    /// editing instead.
    var onSelect: ((WritingPrompt) -> Void)?

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
                                // `.insetGrouped` uppercases headers by
                                // default, which shouted a folder the user
                                // named themselves back at them in caps.
                                Text(folder.name)
                                    .textCase(nil)
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
                                // Was written in caps *and* uppercased again
                                // by the list style — twice as loud as any
                                // other heading in the app.
                                Text(storageService.promptFolders.isEmpty ? "Your questions" : "No folder")
                                    .textCase(nil)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Your questions")
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
                            Label("New question", systemImage: "plus")
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
            Text("Delete folder — keeps its questions")
                .font(Theme.Typography.footnote)
        }
        .listRowBackground(Theme.Colors.cardBackground)
    }

    private func promptRow(_ prompt: WritingPrompt) -> some View {
        // Two targets, because the row means two things. The words select
        // the script; the chevron on the right opens the editor. When there
        // is nothing to select into — browsing from Settings — the words
        // open the editor too, so the row is never inert.
        HStack(spacing: 0) {
            Button {
                AudioService.shared.playUITick()
                if let onSelect {
                    onSelect(prompt)
                    dismiss()
                } else {
                    editingPrompt = prompt
                }
            } label: {
                HStack {
                    Text(prompt.text)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Theme.Spacing.xs)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // No identifier here on purpose. An identifier on a container
            // promotes it to a single accessibility element and hides what
            // is inside — putting one here made the script's own text
            // invisible to VoiceOver and to every query that looks for it.
            // The button carries the script's text as its label already,
            // which is a better handle than an identifier anyway.

            Button {
                AudioService.shared.playUITick()
                editingPrompt = prompt
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
                    .padding(.leading, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("script.edit")
        }
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

            Text("Add your own questions and sort them into folders.")
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
                        Text("QUESTION")
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
            .navigationTitle(editing == nil ? "New question" : "Edit question")
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
