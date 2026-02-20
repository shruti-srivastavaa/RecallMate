import SwiftUI
import CoreData

/// Main entry point for the RecallMate app.
@main
struct RecallMateApp: App {
    let persistence = PersistenceController.shared
    @StateObject private var clipboardMonitor: ClipboardMonitor

    init() {
        let ctx = PersistenceController.shared.container.viewContext
        _clipboardMonitor = StateObject(wrappedValue: ClipboardMonitor(context: ctx))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(clipboardMonitor)
                .onAppear {
                    clipboardMonitor.start()
                    // Initial file scan
                    let scanner = FileScanner(context: persistence.container.viewContext)
                    Task { await scanner.scan() }
                    // Reindex Spotlight
                    SpotlightIndexer.reindexAll(context: persistence.container.viewContext)
                }
                .preferredColorScheme(.dark)
        }
    }
}
