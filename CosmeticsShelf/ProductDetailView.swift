import SwiftData
import SwiftUI

struct ProductDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var product: ProductItem
    @State private var isEditing = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        ProductArtworkView(product: product, size: 88)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.displayName)
                                .font(.title3.weight(.semibold))
                            if let secondaryName = product.secondaryDisplayName {
                                Text(secondaryName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(product.brand.isEmpty ? product.category.localizedTitle : product.brand)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Label(product.status.localizedTitle, systemImage: product.status.symbol)
                        .font(.headline)
                        .foregroundStyle(product.status.tint)
                }
                .padding(.vertical, 6)
            }

            Section(AppStrings.text("保质期", "Shelf Life")) {
                InfoRow(title: AppStrings.text("建议到期日", "Suggested expiry"), value: product.expiryDate?.shelfFormatted ?? AppStrings.text("待补全", "Missing"))
                InfoRow(title: AppStrings.text("提醒开始", "Reminder starts"), value: product.remindFromDate?.shelfFormatted ?? AppStrings.text("待补全", "Missing"))
                InfoRow(title: AppStrings.text("计算依据", "Basis"), value: product.expiryBasis.localizedTitle)
                InfoRow(title: AppStrings.text("未开封", "Unopened"), value: AppStrings.text("\(product.unopenedShelfLifeMonths) 个月", "\(product.unopenedShelfLifeMonths) months"))
                InfoRow(title: AppStrings.text("开封后", "After opening"), value: AppStrings.text("\(product.periodAfterOpeningMonths) 个月", "\(product.periodAfterOpeningMonths) months"))
            }

            Section(AppStrings.text("记录", "Record")) {
                InfoRow(title: AppStrings.text("品类", "Category"), value: product.category.localizedTitle)
                InfoRow(title: AppStrings.text("批号", "Batch code"), value: product.batchCode.isEmpty ? AppStrings.text("未记录", "Not recorded") : product.batchCode)
                InfoRow(title: AppStrings.text("购买日期", "Purchase date"), value: product.purchaseDate.shelfFormatted)
                InfoRow(title: AppStrings.text("生产日期", "Manufacture date"), value: product.manufactureDate?.shelfFormatted ?? AppStrings.text("未记录", "Not recorded"))
                InfoRow(title: AppStrings.text("开封日期", "Opened date"), value: product.openedDate?.shelfFormatted ?? AppStrings.text("未开封", "Unopened"))
                InfoRow(title: AppStrings.text("手动到期日", "Manual expiry"), value: product.manualExpiryDate?.shelfFormatted ?? AppStrings.text("未记录", "Not recorded"))
                InfoRow(title: AppStrings.text("图片链接", "Image URL"), value: product.productImageURL.isEmpty ? AppStrings.text("未记录", "Not recorded") : product.productImageURL)
            }

            if !product.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section(AppStrings.text("备注", "Notes")) {
                    Text(product.notes)
                }
            }

            Section {
                if let officialProduct = product.officialProduct {
                    Button {
                        openURL(officialProduct)
                    } label: {
                        Label(AppStrings.text("打开官网产品页", "Open official product page"), systemImage: "safari")
                    }
                }

                Button {
                    openOfficialImageSearch()
                } label: {
                    Label(AppStrings.text("搜索官网产品图片", "Search official product image"), systemImage: "photo.badge.magnifyingglass")
                }
                .disabled(product.brand.isEmpty || product.displayName.isEmpty)

                Button {
                    openBatchLookup()
                } label: {
                    Label(AppStrings.text("用网页查询批号", "Search batch code"), systemImage: "number")
                }
                .disabled(product.brand.isEmpty || product.batchCode.isEmpty)
            } footer: {
                Text(AppStrings.text("图片和批号结果建议优先使用品牌官网，并和包装、购买渠道一起核对。", "Prefer official brand sources for images and batch results, and cross-check with packaging and retailer records."))
            }
        }
        .navigationTitle(product.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(AppStrings.text("编辑", "Edit")) {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            ProductEditorView(product: product)
        }
    }

    private func openBatchLookup() {
        let query = "\(product.brand) \(product.batchCode) cosmetic batch code"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            openURL(url)
        }
    }

    private func openOfficialImageSearch() {
        let query = "\(product.brand) \(product.displayName) official product image"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            openURL(url)
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: ProductItem.samples[0])
    }
    .modelContainer(for: ProductItem.self, inMemory: true)
}
