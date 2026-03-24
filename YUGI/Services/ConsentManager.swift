import Foundation

final class ConsentManager {
    static let shared = ConsentManager()

    private let currentVersion = "1.0"

    private enum Keys {
        static let hasSeenConsentScreen = "hasSeenConsentScreen"
        static let trackingConsented = "trackingConsented"
        static let consentDate = "consentDate"
        static let consentVersion = "consentVersion"
    }

    private init() {}

    /// Returns true if the user has actively consented to tracking.
    func hasConsented() -> Bool {
        UserDefaults.standard.bool(forKey: Keys.trackingConsented)
    }

    /// Returns true if the consent screen should be shown — either because
    /// the user has never seen it, or because the consent version has changed.
    func needsToShowConsent() -> Bool {
        UserDefaults.standard.string(forKey: Keys.consentVersion) != currentVersion
    }

    /// Records that the user granted consent.
    func grantConsent() {
        UserDefaults.standard.set(true, forKey: Keys.trackingConsented)
        UserDefaults.standard.set(true, forKey: Keys.hasSeenConsentScreen)
        UserDefaults.standard.set(Date(), forKey: Keys.consentDate)
        UserDefaults.standard.set(currentVersion, forKey: Keys.consentVersion)
    }

    /// Records that the user declined or revoked consent.
    func revokeConsent() {
        UserDefaults.standard.set(false, forKey: Keys.trackingConsented)
        UserDefaults.standard.set(true, forKey: Keys.hasSeenConsentScreen)
        UserDefaults.standard.set(Date(), forKey: Keys.consentDate)
        UserDefaults.standard.set(currentVersion, forKey: Keys.consentVersion)
    }
}
