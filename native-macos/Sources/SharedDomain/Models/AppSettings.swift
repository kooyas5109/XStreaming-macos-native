import Foundation

public struct TurnServerConfiguration: Codable, Equatable, Sendable {
    public let url: String
    public let username: String
    public let credential: String

    public init(url: String = "", username: String = "", credential: String = "") {
        self.url = url
        self.username = username
        self.credential = credential
    }
}

public struct DisplayOptions: Codable, Equatable, Sendable {
    public let sharpness: Int
    public let saturation: Int
    public let contrast: Int
    public let brightness: Int

    public init(sharpness: Int, saturation: Int, contrast: Int, brightness: Int) {
        self.sharpness = sharpness
        self.saturation = saturation
        self.contrast = contrast
        self.brightness = brightness
    }
}

public struct InputMouseKeyboardMapping: Codable, Equatable, Sendable {
    public let mapping: [String: String]

    public init(mapping: [String: String]) {
        self.mapping = mapping
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public let locale: String
    public let useMSAL: Bool
    public let fullscreen: Bool
    public let resolution: Int
    public let xhomeAutoConnectServerID: String
    public let xhomeBitrateMode: String
    public let xhomeBitrate: Int
    public let xcloudBitrateMode: String
    public let xcloudBitrate: Int
    public let audioBitrateMode: String
    public let audioBitrate: Int
    public let enableAudioControl: Bool
    public let enableAudioRumble: Bool
    public let audioRumbleThreshold: Double
    public let preferredGameLanguage: String
    public let forceRegionIP: String
    public let codec: String
    public let pollingRate: Int
    public let coop: Bool
    public let vibration: Bool
    public let vibrationMode: String
    public let gamepadKernel: String
    public let gamepadMix: Bool
    public let gamepadIndex: Int
    public let deadZone: Double
    public let edgeCompensation: Int
    public let forceTriggerRumble: String
    public let powerOn: Bool
    public let videoFormat: String
    public let virtualGamepadOpacity: Double
    public let ipv6: Bool
    public let enableNativeMouseKeyboard: Bool
    public let mouseSensitive: Double
    public let performanceStyle: Bool
    public let turnServer: TurnServerConfiguration
    public let backgroundKeepalive: Bool
    public let inputMouseKeyboardMapping: InputMouseKeyboardMapping
    public let displayOptions: DisplayOptions
    public let useVulkan: Bool
    public let fsr: Bool
    public let fsrSharpness: Int
    public let debug: Bool

    public init(
        locale: String,
        useMSAL: Bool,
        fullscreen: Bool,
        resolution: Int,
        xhomeAutoConnectServerID: String,
        xhomeBitrateMode: String,
        xhomeBitrate: Int,
        xcloudBitrateMode: String,
        xcloudBitrate: Int,
        audioBitrateMode: String,
        audioBitrate: Int,
        enableAudioControl: Bool,
        enableAudioRumble: Bool,
        audioRumbleThreshold: Double,
        preferredGameLanguage: String,
        forceRegionIP: String,
        codec: String,
        pollingRate: Int,
        coop: Bool,
        vibration: Bool,
        vibrationMode: String,
        gamepadKernel: String,
        gamepadMix: Bool,
        gamepadIndex: Int,
        deadZone: Double,
        edgeCompensation: Int,
        forceTriggerRumble: String,
        powerOn: Bool,
        videoFormat: String,
        virtualGamepadOpacity: Double,
        ipv6: Bool,
        enableNativeMouseKeyboard: Bool,
        mouseSensitive: Double,
        performanceStyle: Bool,
        turnServer: TurnServerConfiguration,
        backgroundKeepalive: Bool,
        inputMouseKeyboardMapping: InputMouseKeyboardMapping,
        displayOptions: DisplayOptions,
        useVulkan: Bool,
        fsr: Bool,
        fsrSharpness: Int,
        debug: Bool
    ) {
        self.locale = locale
        self.useMSAL = useMSAL
        self.fullscreen = fullscreen
        self.resolution = resolution
        self.xhomeAutoConnectServerID = xhomeAutoConnectServerID
        self.xhomeBitrateMode = xhomeBitrateMode
        self.xhomeBitrate = xhomeBitrate
        self.xcloudBitrateMode = xcloudBitrateMode
        self.xcloudBitrate = xcloudBitrate
        self.audioBitrateMode = audioBitrateMode
        self.audioBitrate = audioBitrate
        self.enableAudioControl = enableAudioControl
        self.enableAudioRumble = enableAudioRumble
        self.audioRumbleThreshold = audioRumbleThreshold
        self.preferredGameLanguage = preferredGameLanguage
        self.forceRegionIP = forceRegionIP
        self.codec = codec
        self.pollingRate = pollingRate
        self.coop = coop
        self.vibration = vibration
        self.vibrationMode = vibrationMode
        self.gamepadKernel = gamepadKernel
        self.gamepadMix = gamepadMix
        self.gamepadIndex = gamepadIndex
        self.deadZone = deadZone
        self.edgeCompensation = edgeCompensation
        self.forceTriggerRumble = forceTriggerRumble
        self.powerOn = powerOn
        self.videoFormat = videoFormat
        self.virtualGamepadOpacity = virtualGamepadOpacity
        self.ipv6 = ipv6
        self.enableNativeMouseKeyboard = enableNativeMouseKeyboard
        self.mouseSensitive = mouseSensitive
        self.performanceStyle = performanceStyle
        self.turnServer = turnServer
        self.backgroundKeepalive = backgroundKeepalive
        self.inputMouseKeyboardMapping = inputMouseKeyboardMapping
        self.displayOptions = displayOptions
        self.useVulkan = useVulkan
        self.fsr = fsr
        self.fsrSharpness = fsrSharpness
        self.debug = debug
    }
}

public extension AppSettings {
    static let defaults = AppSettings(
        locale: "en",
        useMSAL: false,
        fullscreen: false,
        resolution: 720,
        xhomeAutoConnectServerID: "",
        xhomeBitrateMode: "Auto",
        xhomeBitrate: 20,
        xcloudBitrateMode: "Auto",
        xcloudBitrate: 20,
        audioBitrateMode: "Auto",
        audioBitrate: 20,
        enableAudioControl: false,
        enableAudioRumble: false,
        audioRumbleThreshold: 0.15,
        preferredGameLanguage: "en-US",
        forceRegionIP: "",
        codec: "",
        pollingRate: 250,
        coop: false,
        vibration: true,
        vibrationMode: "Native",
        gamepadKernel: "Native",
        gamepadMix: false,
        gamepadIndex: -1,
        deadZone: 0.1,
        edgeCompensation: 0,
        forceTriggerRumble: "",
        powerOn: false,
        videoFormat: "",
        virtualGamepadOpacity: 0.6,
        ipv6: false,
        enableNativeMouseKeyboard: false,
        mouseSensitive: 0.5,
        performanceStyle: false,
        turnServer: TurnServerConfiguration(),
        backgroundKeepalive: false,
        inputMouseKeyboardMapping: InputMouseKeyboardMapping(
            mapping: [
                "ArrowLeft": "DPadLeft",
                "ArrowUp": "DPadUp",
                "ArrowRight": "DPadRight",
                "ArrowDown": "DPadDown",
                "Enter": "A",
                "k": "A",
                "Backspace": "B",
                "l": "B",
                "j": "X",
                "i": "Y",
                "2": "LeftShoulder",
                "3": "RightShoulder",
                "1": "LeftTrigger",
                "4": "RightTrigger",
                "5": "LeftThumb",
                "6": "RightThumb",
                "a": "LeftThumbXAxisPlus",
                "d": "LeftThumbXAxisMinus",
                "w": "LeftThumbYAxisPlus",
                "s": "LeftThumbYAxisMinus",
                "f": "RightThumbXAxisPlus",
                "h": "RightThumbXAxisMinus",
                "t": "RightThumbYAxisPlus",
                "g": "RightThumbYAxisMinus",
                "v": "View",
                "m": "Menu",
                "n": "Nexus"
            ]
        ),
        displayOptions: DisplayOptions(
            sharpness: 5,
            saturation: 100,
            contrast: 100,
            brightness: 100
        ),
        useVulkan: false,
        fsr: false,
        fsrSharpness: 2,
        debug: false
    )
}
