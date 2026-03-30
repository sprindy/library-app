import SwiftUI
import SwiftData

@main
struct LibraryAppApp: App {
    @State private var commandCenter = UICommandCenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(commandCenter)
        }
        .modelContainer(for: [Book.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Book") {
                    commandCenter.triggerNewBook()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .find) {
                Button("Focus Search") {
                    commandCenter.triggerFocusSearch()
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
