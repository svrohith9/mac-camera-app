import SwiftUI

@main
struct CameraPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 540)
        }
        .windowStyle(.automatic)
    }
}
