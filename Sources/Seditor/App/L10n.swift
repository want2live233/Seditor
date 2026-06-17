import Foundation

enum L10n {
    static func t(_ key: String, _ fallback: String) -> String {
        let value = Bundle.module.localizedString(forKey: key, value: fallback, table: "Localizable")
        return value.isEmpty ? fallback : value
    }
}
