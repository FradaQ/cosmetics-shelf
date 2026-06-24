import SwiftUI

enum AppTab: Hashable, CaseIterable, Identifiable {
    case inventory
    case reminders
    case lookup

    var id: Self { self }

    var title: String {
        switch self {
        case .inventory: AppStrings.text("库存", "Inventory")
        case .reminders: AppStrings.text("提醒", "Reminders")
        case .lookup: AppStrings.text("批号", "Batch")
        }
    }

    var symbol: String {
        switch self {
        case .inventory: "shippingbox"
        case .reminders: "bell"
        case .lookup: "magnifyingglass"
        }
    }
}

struct AppRootView: View {
    @State private var selectedTab: AppTab = .inventory

    var body: some View {
        TabView(selection: $selectedTab) {
            InventoryView()
                .tabItem { Label(AppTab.inventory.title, systemImage: AppTab.inventory.symbol) }
                .tag(AppTab.inventory)

            ReminderView()
                .tabItem { Label(AppTab.reminders.title, systemImage: AppTab.reminders.symbol) }
                .tag(AppTab.reminders)

            BatchLookupView()
                .tabItem { Label(AppTab.lookup.title, systemImage: AppTab.lookup.symbol) }
                .tag(AppTab.lookup)
        }
        .task {
            await NotificationScheduler.shared.requestAuthorization()
        }
    }
}
