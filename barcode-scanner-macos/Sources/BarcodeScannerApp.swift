import SwiftUI

@main
struct BarcodeScannerApp: App {
    @StateObject private var scanner = ScannerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanner)
                .frame(minWidth: 780, minHeight: 520)
                .onAppear {
                    scanner.requestAccessAndStart()
                }
                .onDisappear {
                    scanner.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

