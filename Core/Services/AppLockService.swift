import Foundation
import Combine
import CryptoKit
import LocalAuthentication

/// The app lock: a private journal should be able to stay private on a phone
/// someone else is holding.
///
/// Two independent pieces of state, and they are not the same thing:
///
/// - `isLocked` — the gate. Cleared only by Face ID / Touch ID or the code.
///   Set on cold launch and on a real return from the background.
/// - `isObscured` — the app-switcher cover. Set the moment the app goes
///   `.inactive` so the snapshot iOS takes for the switcher shows a blank
///   card instead of a page of someone's handwriting. Cleared on `.active`
///   with no authentication, because nothing was ever unlocked.
///
/// Keeping them apart is what stops the brightness-service mistake from
/// repeating: `.inactive` also fires for a pulled-down Control Center or a
/// notification banner, and locking on that would throw the user out of a
/// session they are still sitting in front of. Only `.background` locks.
///
/// The code itself is never stored. A random salt and a SHA-256 of
/// salt-plus-code go to the Keychain, marked `ThisDeviceOnly` so the lock
/// does not travel to a restored backup on another phone. People reuse
/// passcodes; a Keychain dump should not hand over the one they also use on
/// their front door.
///
/// There is deliberately no recovery path. Everything Verg holds is local —
/// there is no server to reset against, so a "forgot code" door would have to
/// open for whoever is holding the phone, which is precisely the person the
/// lock exists to stop. The set-up screen says so in plain words before the
/// code is accepted.
@MainActor
final class AppLockService: ObservableObject {

    static let shared = AppLockService()

    /// How the code is entered, which decides the keyboard and whether entry
    /// can submit itself. Not a secret — the keyboard gives it away — so it
    /// lives in `UserDefaults` rather than the Keychain.
    enum CodeStyle: String {
        /// Four digits, number pad, submits on the fourth.
        case fourDigit
        /// A written code of any length, with a Done key.
        case passphrase
    }

    // MARK: - Published state

    /// The gate is up and the app's contents are unreachable.
    @Published private(set) var isLocked: Bool = false

    /// A cover for the app-switcher snapshot. Not a lock — see the type note.
    @Published private(set) var isObscured: Bool = false

    /// Whether a code has been set. Derived from the Keychain at init and
    /// kept in step by `setCode`/`disable`, so it cannot drift from reality.
    @Published private(set) var isEnabled: Bool = false

    @Published private(set) var codeStyle: CodeStyle = .fourDigit

    /// When code entry opens again after too many wrong codes, or `nil` if
    /// it is open now. Face ID / Touch ID are not affected — see
    /// `lockoutDuration(afterFailures:)`.
    @Published private(set) var lockedOutUntil: Date?

    // MARK: - Storage keys

    private let service = "app.verg.lock"
    private let account = "passcode"
    private let attemptsAccount = "failedAttempts"
    private let styleDefaultsKey = "verg.appLock.codeStyle"

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        switch readRecord() {
        case .found:
            isEnabled = true
        case .absent:
            isEnabled = false
        case .unreadable:
            // Fail closed. The Keychain refused to answer (most likely
            // protected data is not available yet), which says nothing about
            // whether a code exists. Treating that as "no code" would open a
            // locked journal; `resyncWithKeychain()` settles it once the
            // Keychain answers.
            isEnabled = true
        }
        codeStyle = CodeStyle(rawValue: defaults.string(forKey: styleDefaultsKey) ?? "") ?? .fourDigit
        // A cold launch of a locked app starts locked. Nothing to unlock if
        // no code was ever set.
        isLocked = isEnabled
        lockedOutUntil = activeLockoutEnd()
    }

    /// Re-read the Keychain and correct `isEnabled` if init had to guess.
    ///
    /// The only correction that changes what the user sees is "init failed
    /// closed, but there is in fact no code" — then the gate comes down,
    /// since there is no code that could ever open it.
    func resyncWithKeychain() {
        switch readRecord() {
        case .found:
            isEnabled = true
        case .absent:
            if isEnabled {
                isEnabled = false
                isLocked = false
            }
        case .unreadable:
            break
        }
        lockedOutUntil = activeLockoutEnd()
    }

    // MARK: - Enabling and disabling

    /// Set (or replace) the code and turn the lock on.
    ///
    /// Returns `false` only if the Keychain write fails, which leaves the
    /// previous state untouched rather than half-applied — a lock that
    /// silently failed to save is worse than one that reports it.
    @discardableResult
    func setCode(_ code: String, style: CodeStyle) -> Bool {
        let salt = Self.randomSalt()
        let record = Record(salt: salt, hash: Self.hash(code: code, salt: salt))
        guard save(record) else { return false }
        clearFailures()
        defaults.set(style.rawValue, forKey: styleDefaultsKey)
        codeStyle = style
        isEnabled = true
        // Setting a code does not lock you out of the screen you set it on.
        isLocked = false
        return true
    }

    /// Turn the lock off and forget the code. Caller is responsible for
    /// having authenticated first — Settings requires the current code.
    func disable() {
        deleteRecord()
        clearFailures()
        isEnabled = false
        isLocked = false
    }

    // MARK: - Unlocking

    /// Check a code against the stored hash, counting wrong ones.
    ///
    /// While a lockout is running this returns `false` without looking at
    /// the code and without counting it, so waiting it out is the only way
    /// forward. Every caller — the lock screen and the confirm-to-disable
    /// sheet — goes through here, so neither can be used to guess faster.
    func verify(_ code: String) -> Bool {
        if let end = activeLockoutEnd() {
            lockedOutUntil = end
            return false
        }
        guard case .found(let record) = readRecord() else { return false }
        let candidate = Self.hash(code: code, salt: record.salt)
        // Compare the digests, not the codes. Equal-length fixed digests, so
        // there is no length side channel to leak.
        if candidate == record.hash {
            clearFailures()
            return true
        }
        registerFailure()
        return false
    }

    /// Seconds until code entry opens again, or `nil` if it is open now.
    func lockoutRemaining(at now: Date = Date()) -> TimeInterval? {
        guard let until = lockedOutUntil, until > now else { return nil }
        return until.timeIntervalSince(now)
    }

    // MARK: - Wrong-code throttling

    /// How long code entry stays closed after the `failures`-th wrong code
    /// in a row.
    ///
    /// A four-digit code has 10,000 possibilities, and without this all of
    /// them could be tried in under an hour by whoever is holding the phone,
    /// which is exactly the person the lock is for. The first four mistakes
    /// are free (typos happen), then the wait climbs to an hour per attempt,
    /// which puts working through the code space at months, not minutes.
    ///
    /// Face ID / Touch ID stay available throughout, so the owner is never
    /// made to wait. The count lives in the Keychain alongside the code, so
    /// force-quitting or reinstalling does not reset it.
    nonisolated static func lockoutDuration(afterFailures failures: Int) -> TimeInterval {
        switch failures {
        case ..<5: return 0
        case 5: return 60
        case 6: return 5 * 60
        case 7: return 15 * 60
        default: return 60 * 60
        }
    }

    /// When code entry reopens, given the failure count and when the last
    /// wrong code was entered. `nil` if there is no wait.
    nonisolated static func lockoutEnd(failures: Int, lastFailure: Date) -> Date? {
        let duration = lockoutDuration(afterFailures: failures)
        guard duration > 0 else { return nil }
        return lastFailure.addingTimeInterval(duration)
    }

    private struct FailureRecord: Codable {
        var count: Int
        var lastFailure: Date
    }

    /// The end of the current lockout if one is running now.
    ///
    /// A last failure dated in the future means the clock was turned back
    /// after it. That is re-anchored to now, so the wait is served once in
    /// full instead of stretching until the clock catches up. Turning the
    /// clock *forward* does shorten a wait. Closing that needs a trusted time
    /// source, and changing the clock still means one attempt per change.
    private func activeLockoutEnd(now: Date = Date()) -> Date? {
        guard var record = loadFailures() else { return nil }
        if record.lastFailure > now {
            record.lastFailure = now
            saveFailures(record)
        }
        guard let end = Self.lockoutEnd(failures: record.count, lastFailure: record.lastFailure),
              end > now else { return nil }
        return end
    }

    /// A day without a wrong code starts the count over, so the odd typo
    /// spread across weeks never adds up to a lockout. Guessing still has
    /// to happen in one sitting, which the schedule makes slow.
    nonisolated static let failureMemory: TimeInterval = 24 * 60 * 60

    /// The count a new wrong code builds on, given the stored one.
    nonisolated static func priorFailures(count: Int, lastFailure: Date, now: Date) -> Int {
        now.timeIntervalSince(lastFailure) > failureMemory ? 0 : count
    }

    private func registerFailure(now: Date = Date()) {
        var record = loadFailures() ?? FailureRecord(count: 0, lastFailure: now)
        record.count = Self.priorFailures(count: record.count, lastFailure: record.lastFailure, now: now)
        record.count += 1
        record.lastFailure = now
        saveFailures(record)
        lockedOutUntil = Self.lockoutEnd(failures: record.count, lastFailure: now)
    }

    private func clearFailures() {
        SecItemDelete(keychainQuery(for: attemptsAccount) as CFDictionary)
        lockedOutUntil = nil
    }

    /// Verify and, on success, open the gate.
    func unlock(with code: String) -> Bool {
        guard verify(code) else { return false }
        isLocked = false
        return true
    }

    /// Face ID / Touch ID, if the phone has it and the user has enrolled.
    ///
    /// `.deviceOwnerAuthenticationWithBiometrics` rather than
    /// `.deviceOwnerAuthentication`: the latter falls back to the *device*
    /// passcode, which would let anyone who can unlock the phone walk past a
    /// lock whose entire purpose is to stop exactly that. The fallback here
    /// is Verg's own code, offered by the lock screen.
    func authenticateWithBiometrics() async -> Bool {
        guard isEnabled else { return true }
        let context = LAContext()
        context.localizedFallbackTitle = ""   // we present our own code entry
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return false
        }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your journal."
            )
            if ok {
                isLocked = false
                // The owner has proved themselves, so wrong codes typed
                // before this (theirs or anyone's) stop counting.
                clearFailures()
            }
            return ok
        } catch {
            // Cancelled, or too many failed attempts. The code entry stays.
            return false
        }
    }

    /// What the phone actually offers, for labelling the button honestly.
    var biometryType: LABiometryType {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        return context.biometryType
    }

    var biometryLabel: String? {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return nil
        }
    }

    var biometryIcon: String? {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return nil
        }
    }

    // MARK: - Scene phase

    /// A real backgrounding. Locks.
    ///
    /// Both pieces of state are gated on `isEnabled`: with no code set there
    /// is nothing to protect, and an unconditional cover here is what made
    /// the "Verg is locked" card flash during swipe-between-apps gestures
    /// for users who had never turned the lock on — the gesture hands the
    /// app a brief `.background`, this set the cover, and the paired
    /// `.active` could land while nobody was rendering to clear it.
    func handleDidEnterBackground() {
        guard isEnabled else { return }
        isObscured = true
        isLocked = true
    }

    /// Momentary — Control Center, a banner, the app switcher. Covers the
    /// snapshot but does *not* lock; see the type note.
    func handleWillResignActive() {
        guard isEnabled else { return }
        isObscured = true
    }

    func handleDidBecomeActive() {
        // Cleared unconditionally: if the lock was disabled while a cover
        // was up (or a pre-fix build left one behind), coming back to the
        // front must always return the screen, not preserve the card.
        isObscured = false
        // If init could not read the Keychain it failed closed; settle that
        // now that the app is in front and the device is unlocked.
        resyncWithKeychain()
    }

    // MARK: - Hashing

    private struct Record {
        let salt: Data
        let hash: Data
    }

    private static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        // SecRandomCopyBytes is the only source here; a failure is not
        // recoverable by falling back to something weaker, so it traps.
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Unable to generate salt")
        return Data(bytes)
    }

    private static func hash(code: String, salt: Data) -> Data {
        // Normalise before hashing so a written code that round-trips through
        // a different keyboard still matches. Digits are unaffected.
        let normalized = code.precomposedStringWithCanonicalMapping
        var input = salt
        input.append(Data(normalized.utf8))
        return Data(SHA256.hash(data: input))
    }

    // MARK: - Keychain

    private var baseQuery: [String: Any] { keychainQuery(for: account) }

    private func keychainQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// The outcome of reading the code, keeping "there is no code" apart
    /// from "the Keychain would not say". Collapsing the two is what let a
    /// failed read switch the lock off.
    private enum RecordRead {
        case found(Record)
        case absent
        case unreadable
    }

    private func save(_ record: Record) -> Bool {
        var payload = record.salt
        payload.append(record.hash)

        // Delete-then-add rather than update: one code path, and it cannot
        // leave a stale record behind if the attributes ever change.
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = payload
        // ThisDeviceOnly: the lock should not ride along to a restored backup
        // on a different phone, where the code's owner may not be present.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func readRecord() -> RecordRead {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            // A malformed item can never match any code, so treating it as
            // locked would lock the owner out for good with no way back.
            // It counts as no code, as it always has.
            guard let data = item as? Data, data.count == 48 else {   // 16 salt + 32 digest
                return .absent
            }
            return .found(Record(salt: data.prefix(16), hash: data.suffix(32)))
        case errSecItemNotFound:
            return .absent
        default:
            // errSecInteractionNotAllowed (device locked) and anything else.
            return .unreadable
        }
    }

    private func deleteRecord() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private func loadFailures() -> FailureRecord? {
        var query = keychainQuery(for: attemptsAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(FailureRecord.self, from: data)
    }

    private func saveFailures(_ record: FailureRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        let base = keychainQuery(for: attemptsAccount)
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
