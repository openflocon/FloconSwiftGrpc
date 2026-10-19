import FloconGrpc
import SwiftUI

@main
struct FloconGrpcDemoApp: App {
    init() {
        // Flocon.initialize(config: FloconConfig(host: "192.168.1.20")) // on a real iPhone
        Flocon.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
