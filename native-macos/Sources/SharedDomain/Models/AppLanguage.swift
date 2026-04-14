import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Equatable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public init(localeCode: String) {
        if localeCode.lowercased().hasPrefix("zh") {
            self = .simplifiedChinese
        } else {
            self = .english
        }
    }

    public var localeCode: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Chinese (Simplified)"
        }
    }

    public var nativeDisplayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }
}
