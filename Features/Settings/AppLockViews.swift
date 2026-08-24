import SwiftUI

// MARK: - Code Entry Field

/// The one place a code is typed, shared by the lock screen, the set-up
/// sheet and the confirm-to-disable sheet, so all three agree on keyboard,
/// obscuring and submit behaviour.
///
/// A four-digit code submits itself on the fourth digit; a written one waits
/// for Done. The style is known because it is stored alongside the hash — see
/// `AppLockService.CodeStyle`.
struct AppLockCodeField: View {
    let style: AppLockService.CodeStyle
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        SecureField(placeholder, text: $text)
            .textContentType(.oneTimeCode)   // suppresses the strong-password sheet
            .keyboardType(style == .fourDigit ? .numberPad : .default)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.center)
            .font(style == .fourDigit
                  ? .system(size: 28, weight: .semibold, design: .monospaced)
                  : Theme.Typography.body)
            .foregroundColor(Theme.Colors.primaryText)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
            .onChange(of: text) { _, value in
                guard style == .fourDigit else { return }
                // Number pad still admits paste; keep it to digits and cap it.
                let digits = value.filter(\.isNumber)
                if digits != value { text = String(digits.prefix(4)); return }
                if digits.count > 4 { text = String(digits.prefix(4)); return }
                if digits.count == 4 { onSubmit() }
            }
            .onAppear { focused = true }
            .accessibilityIdentifier("applock.codeField")
    }
}

// MARK: - Lock Screen

/// The gate. Covers everything until Face ID or the code opens it.
///
/// Biometrics fire once on appear rather than behind a button tap — that is
/// what every system-standard lock does, and making the common case a tap is
/// friction for no security. The code stays on screen the whole time as the
/// fallback, so a failed or cancelled scan needs no second gesture.
struct AppLockScreen: View {
    @ObservedObject var lock: AppLockService

    @State private var code: String = ""
    @State private var failed: Bool = false
    @State private var shake: CGFloat = 0
    /// Guards against re-prompting on every re-render while a scan is up.
    @State private var biometricsAttempted = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                Text("🕯️")
                    .font(.system(size: 44))

                Text("Verg is locked")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.primaryText)

                VStack(spacing: Theme.Spacing.sm) {
                    AppLockCodeField(
                        style: lock.codeStyle,
                        placeholder: lock.codeStyle == .fourDigit ? "••••" : "Code",
                        text: $code,
                        onSubmit: attemptUnlock
                    )
                    .frame(maxWidth: lock.codeStyle == .fourDigit ? 180 : .infinity)
                    .offset(x: shake)

                    if failed {
                        Text("Wrong code.")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(.red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                if let label = lock.biometryLabel, let icon = lock.biometryIcon {
                    Button {
                        Task { await runBiometrics() }
                    } label: {
                        Label("Unlock with \(label)", systemImage: icon)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(.top, Theme.Spacing.xxs)
                    .accessibilityIdentifier("applock.biometrics")
                }

                Spacer()
                Spacer()
            }
        }
        .task {
            guard !biometricsAttempted else { return }
            biometricsAttempted = true
            await runBiometrics()
        }
        // No identifier on this container. An `accessibilityIdentifier` on a
        // SwiftUI container can promote it to a single accessibility element
        // and hide its children — which it did here, making the code field
        // unreachable to both VoiceOver and the UI tests while the identical
        // field inside the set-up sheet was fine. The title text identifies
        // the screen instead.
    }

    private func runBiometrics() async {
        _ = await lock.authenticateWithBiometrics()
    }

    private func attemptUnlock() {
        guard !code.isEmpty else { return }
        if lock.unlock(with: code) {
            code = ""
            failed = false
        } else {
            withAnimation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)) {
                shake = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                shake = 0
            }
            withAnimation { failed = true }
            code = ""
        }
    }
}

// MARK: - Set-up Sheet

/// Choose a style, enter a code, confirm it. The no-recovery warning is on
/// screen before the code is accepted, not buried after the fact — losing the
/// code means losing the journal, and that has to be said up front.
struct AppLockSetupSheet: View {
    @ObservedObject var lock: AppLockService
    /// Called with `true` once a code is set, `false` if the user backs out —
    /// Settings uses it to put the toggle back where it was.
    let onFinish: (Bool) -> Void

    @State private var style: AppLockService.CodeStyle = .fourDigit
    @State private var first: String = ""
    @State private var second: String = ""
    @State private var stage: Stage = .enter
    @State private var error: String?

    private enum Stage { case enter, confirm }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    if stage == .enter {
                        Picker("Code style", selection: $style) {
                            Text("4 digits").tag(AppLockService.CodeStyle.fourDigit)
                            Text("Written").tag(AppLockService.CodeStyle.passphrase)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: style) { _, _ in
                            first = ""; second = ""; error = nil
                        }
                        .accessibilityIdentifier("applock.stylePicker")
                    }

                    Text(stage == .enter ? "Choose a code." : "Enter it again.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)

                    AppLockCodeField(
                        style: style,
                        placeholder: style == .fourDigit ? "••••" : "Code",
                        text: stage == .enter ? $first : $second,
                        onSubmit: advance
                    )
                    .frame(maxWidth: style == .fourDigit ? 180 : .infinity)
                    // A fresh field per stage, so the number pad's
                    // submit-on-fourth-digit doesn't fire against stale text.
                    .id(stage)

                    if let error {
                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(.red)
                    }

                    Text("If you forget this code, there is no way back into your journal. Verg keeps everything on your phone — there is no account to reset it from.")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.sm)

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Lock App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onFinish(false) }
                        .foregroundColor(Theme.Colors.accent)
                }
                if style == .passphrase {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(stage == .enter ? "Next" : "Set") { advance() }
                            .foregroundColor(Theme.Colors.accent)
                            .disabled(currentText.isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private var currentText: String {
        stage == .enter ? first : second
    }

    private func advance() {
        error = nil
        switch stage {
        case .enter:
            guard !first.isEmpty else { return }
            if style == .fourDigit && first.count != 4 {
                error = "Four digits."
                return
            }
            stage = .confirm
        case .confirm:
            guard !second.isEmpty else { return }
            guard first == second else {
                error = "Those didn't match."
                second = ""
                stage = .enter
                first = ""
                return
            }
            guard lock.setCode(first, style: style) else {
                error = "Couldn't save the code. Try again."
                return
            }
            onFinish(true)
        }
    }
}

// MARK: - Confirm Sheet

/// Turning the lock *off* requires the current code. Without this the lock
/// is decorative: anyone holding an unlocked phone could flip the switch in
/// Settings and walk straight in.
struct AppLockConfirmSheet: View {
    @ObservedObject var lock: AppLockService
    let onFinish: (Bool) -> Void

    @State private var code: String = ""
    @State private var error: String?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    Text("Enter your code to turn the lock off.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)

                    AppLockCodeField(
                        style: lock.codeStyle,
                        placeholder: lock.codeStyle == .fourDigit ? "••••" : "Code",
                        text: $code,
                        onSubmit: attempt
                    )
                    .frame(maxWidth: lock.codeStyle == .fourDigit ? 180 : .infinity)

                    if let error {
                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(.red)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Lock App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onFinish(false) }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func attempt() {
        guard !code.isEmpty else { return }
        if lock.verify(code) {
            lock.disable()
            onFinish(true)
        } else {
            error = "Wrong code."
            code = ""
        }
    }
}
