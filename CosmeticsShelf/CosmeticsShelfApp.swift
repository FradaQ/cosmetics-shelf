import SwiftData
import SwiftUI

@main
struct CosmeticsShelfApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: ProductItem.self)
    }
}

