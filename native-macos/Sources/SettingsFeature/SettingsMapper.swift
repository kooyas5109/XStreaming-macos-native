import SharedDomain

public enum SettingsMapper {
    public static func withUpdatedTurnServer(
        from settings: AppSettings,
        url: String,
        username: String,
        credential: String
    ) -> AppSettings {
        AppSettings(
            locale: settings.locale,
            useMSAL: settings.useMSAL,
            fullscreen: settings.fullscreen,
            resolution: settings.resolution,
            xhomeAutoConnectServerID: settings.xhomeAutoConnectServerID,
            xhomeBitrateMode: settings.xhomeBitrateMode,
            xhomeBitrate: settings.xhomeBitrate,
            xcloudBitrateMode: settings.xcloudBitrateMode,
            xcloudBitrate: settings.xcloudBitrate,
            audioBitrateMode: settings.audioBitrateMode,
            audioBitrate: settings.audioBitrate,
            enableAudioControl: settings.enableAudioControl,
            enableAudioRumble: settings.enableAudioRumble,
            audioRumbleThreshold: settings.audioRumbleThreshold,
            preferredGameLanguage: settings.preferredGameLanguage,
            forceRegionIP: settings.forceRegionIP,
            codec: settings.codec,
            pollingRate: settings.pollingRate,
            coop: settings.coop,
            vibration: settings.vibration,
            vibrationMode: settings.vibrationMode,
            gamepadKernel: settings.gamepadKernel,
            gamepadMix: settings.gamepadMix,
            gamepadIndex: settings.gamepadIndex,
            deadZone: settings.deadZone,
            edgeCompensation: settings.edgeCompensation,
            forceTriggerRumble: settings.forceTriggerRumble,
            powerOn: settings.powerOn,
            videoFormat: settings.videoFormat,
            virtualGamepadOpacity: settings.virtualGamepadOpacity,
            ipv6: settings.ipv6,
            enableNativeMouseKeyboard: settings.enableNativeMouseKeyboard,
            mouseSensitive: settings.mouseSensitive,
            performanceStyle: settings.performanceStyle,
            turnServer: TurnServerConfiguration(
                url: url,
                username: username,
                credential: credential
            ),
            backgroundKeepalive: settings.backgroundKeepalive,
            inputMouseKeyboardMapping: settings.inputMouseKeyboardMapping,
            displayOptions: settings.displayOptions,
            useVulkan: settings.useVulkan,
            fsr: settings.fsr,
            fsrSharpness: settings.fsrSharpness,
            debug: settings.debug
        )
    }
}
