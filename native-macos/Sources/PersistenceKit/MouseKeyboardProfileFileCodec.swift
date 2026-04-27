import Foundation
import SharedDomain

public enum MouseKeyboardProfileImportPayload: Sendable {
    case profiles(MouseKeyboardProfiles)
    case profile(MouseKeyboardMappingProfile)
}

public enum MouseKeyboardProfileFileCodec {
    public static func readImportPayload(from url: URL) throws -> MouseKeyboardProfileImportPayload {
        let data = try Data(contentsOf: url)

        if let profiles = try? JSONDecoder().decode(MouseKeyboardProfiles.self, from: data) {
            return .profiles(profiles)
        }

        return .profile(try JSONDecoder().decode(MouseKeyboardMappingProfile.self, from: data))
    }

    public static func writeProfile(_ profile: MouseKeyboardMappingProfile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
    }

    public static func writeProfiles(_ profiles: MouseKeyboardProfiles, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: url, options: .atomic)
    }
}
