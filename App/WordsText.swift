import Foundation
import ReelsmithCore

/// Looks the key of a `Words` value up in `Localizable.strings` and puts its arguments in at %1$@, %2$@ and so on.
///
/// https://developer.apple.com/documentation/foundation/bundle/localizedstring(forkey:value:table:)
func text(_ words: Words) -> String {
    var result = Bundle.main.localizedString(forKey: words.key, value: nil, table: nil)
    for (index, argument) in words.arguments.enumerated() {
        result = result.replacingOccurrences(of: "%" + String(index + 1) + "$@", with: argument)
    }
    return result
}
