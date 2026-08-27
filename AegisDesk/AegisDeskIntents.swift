import AppIntents
import Foundation

private enum AegisIntentRoute {
    static func request(_ section: String, prompt: String = "") {
        UserDefaults.standard.set(section, forKey: "requestedSection")
        if !prompt.isEmpty {
            UserDefaults.standard.set(prompt, forKey: "requestedAssistantPrompt")
        }
    }
}

struct OpenAegisAssistantIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AegisDesk Assistant"
    static let description = IntentDescription("Opens the secure AI assistant in AegisDesk.")
    static let openAppWhenRun = true

    @Parameter(title: "Request") var request: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { AegisIntentRoute.request("AI Assistant", prompt: request ?? "") }
        return .result(dialog: "Opening the AegisDesk assistant.")
    }
}

struct OpenAegisPlannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AegisDesk Planner"
    static let description = IntentDescription("Opens your planner and focus tools.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { AegisIntentRoute.request("Planner") }
        return .result(dialog: "Opening your AegisDesk planner.")
    }
}

struct OpenAegisCreativeStudioIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AegisDesk Creative Studio"
    static let description = IntentDescription("Opens the image creation studio.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { AegisIntentRoute.request("Creative Studio") }
        return .result(dialog: "Opening Creative Studio.")
    }
}

struct OpenAegisSecurityIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AegisDesk Security"
    static let description = IntentDescription("Opens protected security settings. Authentication may be required.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { AegisIntentRoute.request("Settings") }
        return .result(dialog: "Opening protected AegisDesk settings.")
    }
}

struct AegisDeskShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAegisAssistantIntent(),
            phrases: ["Ask \(.applicationName)", "Open the assistant in \(.applicationName)"],
            shortTitle: "Ask AegisDesk",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenAegisPlannerIntent(),
            phrases: ["Plan my day with \(.applicationName)", "Open my \(.applicationName) planner"],
            shortTitle: "Open Planner",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: OpenAegisCreativeStudioIntent(),
            phrases: ["Create with \(.applicationName)", "Open Creative Studio in \(.applicationName)"],
            shortTitle: "Create an Image",
            systemImageName: "wand.and.stars"
        )
        AppShortcut(
            intent: OpenAegisSecurityIntent(),
            phrases: ["Open security in \(.applicationName)"],
            shortTitle: "Security Settings",
            systemImageName: "lock.shield"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .navy }
}
