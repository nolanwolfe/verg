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

    // MARK: - Storage keys

    private let service = "app.verg.lock"
    private let account = "passcode"
    private let styleDefaultsKey = "verg.appLock.codeStyle"

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = loadRecord()
        isEnabled = stored != nil
        codeStyle = CodeStyle(rawValue: defaults.string(forKey: styleDefaultsKey) ?? "") ?? .fourDigit
        // A cold launch of a locked app starts locked. Nothing to unlock if
        // no code was ever set.
        isLocked = isEnabled
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
        isEnabled = false
        isLocked = false
    }

    // MARK: - Unlocking

    /// Constant-time-ish comparison against the stored hash.
    func verify(_ code: String) -> Bool {
        guard let record = loadRecord() else { return false }
        let candidate = Self.hash(code: code, salt: record.salt)
        // Compare the digests, not the codes. Equal-length fixed digests, so
        // there is no length side channel to leak.
        return candidate == record.hash
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
            if ok { isLocked = false }
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
    func handleDidEnterBackground() {
        isObscured = true
        if isEnabled { isLocked = true }
    }

    /// Momentary — Control Center, a banner, the app switcher. Covers the
    /// snapshot but does *not* lock; see the type note.
    func handleWillResignActive() {
        if isEnabled { isObscured = true }
    }

    func handleDidBecomeActive() {
        isObscured = false
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

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
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

    private func loadRecord() -> Record? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              data.count == 48 else {           // 16 salt + 32 digest
            return nil
        }
        return Record(salt: data.prefix(16), hash: data.suffix(32))
    }

    private func deleteRecord() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
