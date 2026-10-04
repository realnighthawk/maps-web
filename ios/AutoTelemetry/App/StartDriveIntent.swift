import AppIntents

/// "Start drive" for the Shortcuts app. In Shortcuts, make a personal automation: "When CarPlay connects" (or "When
/// <your car's Bluetooth> connects") then "Start drive", and the app connects to your car's adapter as you get in.
/// It opens the app, which keeps the location access a drive needs.
struct StartDriveIntent: AppIntent {
    static var title: LocalizedStringResource = "Start drive"
    static var description = IntentDescription("Connects to the adapter in the car you drove last and starts recording a drive.")
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let started = await AppModel.shared.autoStartDrive()
        return .result(dialog: started
            ? "Connecting to your car."
            : "Couldn't start a drive. Set up your car's adapter in AutoTelemetry first.")
    }
}

/// "Stop drive" for Shortcuts: an automation "When CarPlay disconnects" then "Stop drive" ends the drive without CarPlay's
/// entitlement. Runs in the background; it does nothing if no drive is running.
struct StopDriveIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop drive"
    static var description = IntentDescription("Ends the drive that is being recorded.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let drive = AppModel.shared.drive
        guard drive.busy else { return .result(dialog: "No drive is running.") }
        drive.stop()
        return .result(dialog: "Drive ended.")
    }
}

struct AutoTelemetryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartDriveIntent(), phrases: ["Start a drive in \(.applicationName)"],
                    shortTitle: "Start drive", systemImageName: "play.fill")
        AppShortcut(intent: StopDriveIntent(), phrases: ["End my drive in \(.applicationName)"],
                    shortTitle: "Stop drive", systemImageName: "stop.fill")
    }
}
