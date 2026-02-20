import AppIntents

/// Registers Siri shortcut phrases for the RecallMate.
struct RecallMateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecallMemoryIntent(),
            phrases: [
                "Recall \(\.$query) in \(.applicationName)",
                "Search \(\.$query) in \(.applicationName)",
                "Find \(\.$query) in \(.applicationName)",
                "What was \(\.$query) in \(.applicationName)",
                "Where is \(\.$query) in \(.applicationName)"
            ],
            shortTitle: "Recall Memory",
            systemImageName: "brain.head.profile"
        )
    }
}
