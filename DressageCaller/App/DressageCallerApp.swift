import SwiftUI

@main
struct DressageCallerApp: App {
    @State private var importURL: URL?

    var body: some Scene {
        WindowGroup {
            HomeView(importURL: $importURL)
        }
        .onOpenURL { url in
            guard url.pathExtension.lowercased() == "pdf" else { return }
            importURL = url
        }
    }
}
