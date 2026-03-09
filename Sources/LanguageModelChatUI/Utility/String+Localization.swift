import Foundation

extension String {
    static func localized(
        _ value: String.LocalizationValue,
        table: String? = nil,
        bundle: Bundle = LanguageModelChatInterfaceConfiguration.localizationBundle
    ) -> String {
        String(localized: value, table: table, bundle: bundle)
    }
}
