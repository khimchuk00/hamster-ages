import Foundation

/// Localization for strings built outside SwiftUI literals (model titles, banners, notifications).
/// Keys are the English text; translations live in `Localizable.xcstrings`. Integers use `%lld`, strings `%@`.
public enum L10n {
    public static func t(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    public static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: Locale.current, arguments: args)
    }
}
