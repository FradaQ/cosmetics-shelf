import SwiftData
import SwiftUI

struct ReminderView: View {
    @Query(sort: \ProductItem.createdAt, order: .reverse) private var products: [ProductItem]

    private var attentionProducts: [ProductItem] {
        products
            .filter { $0.status == .expired || $0.status == .useSoon || $0.status == .unknown }
            .sorted { lhs, rhs in
                switch (lhs.expiryDate, rhs.expiryDate) {
                case let (left?, right?): left < right
                case (.some, nil): true
                case (nil, .some): false
                case (nil, nil): lhs.name < rhs.name
                }
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if attentionProducts.isEmpty {
                    ContentUnavailableView(
                        AppStrings.text("暂时不用担心", "Nothing urgent"),
                        systemImage: "checkmark.circle",
                        description: Text(AppStrings.text("距离建议到期半年内的产品会出现在这里。", "Products within 6 months of suggested expiry will appear here."))
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section(AppStrings.text("优先使用", "Use First")) {
                        ForEach(attentionProducts) { product in
                            NavigationLink {
                                ProductDetailView(product: product)
                            } label: {
                                ProductRow(product: product)
                            }
                        }
                    }
                }

                Section(AppStrings.text("提醒规则", "Reminder Rules")) {
                    Label(AppStrings.text("建议到期日前 6 个月发送本地通知", "Send a local notification 6 months before suggested expiry"), systemImage: "bell.badge")
                    Label(AppStrings.text("过期和日期缺失的产品会一直显示在这里", "Expired items and items missing dates stay visible here"), systemImage: "list.bullet.clipboard")
                }
            }
            .navigationTitle(AppStrings.text("使用提醒", "Use Reminders"))
        }
    }
}

#Preview {
    ReminderView()
        .modelContainer(for: ProductItem.self, inMemory: true)
}
