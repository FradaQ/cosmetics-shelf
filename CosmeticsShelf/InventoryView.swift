import SwiftData
import SwiftUI

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProductItem.createdAt, order: .reverse) private var products: [ProductItem]
    @State private var selectedCategory: ProductCategory?
    @State private var searchText = ""
    @State private var isPresentingEditor = false

    private var filteredProducts: [ProductItem] {
        products.filter { product in
            let matchesCategory = selectedCategory == nil || product.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || product.name.localizedCaseInsensitiveContains(query)
                || product.localName.localizedCaseInsensitiveContains(query)
                || product.englishName.localizedCaseInsensitiveContains(query)
                || product.brand.localizedCaseInsensitiveContains(query)
                || product.batchCode.localizedCaseInsensitiveContains(query)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CategoryPicker(selectedCategory: $selectedCategory, products: products)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if products.isEmpty {
                    ContentUnavailableView(
                        AppStrings.text("还没有库存", "No inventory yet"),
                        systemImage: "shippingbox",
                        description: Text(AppStrings.text("添加护肤品、彩妆或香水后，这里会按品类和到期状态整理。", "Add skincare, makeup, or fragrance items and they will be organized by category and expiry status."))
                    )
                    .listRowBackground(Color.clear)
                } else if filteredProducts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                } else {
                    Section(AppStrings.text("产品", "Products")) {
                        ForEach(filteredProducts) { product in
                            NavigationLink {
                                ProductDetailView(product: product)
                            } label: {
                                ProductRow(product: product)
                            }
                        }
                        .onDelete(perform: deleteProducts)
                    }
                }
            }
            .navigationTitle(AppStrings.text("美妆库存", "Beauty Shelf"))
            .searchable(text: $searchText, prompt: AppStrings.text("搜索品牌、产品或批号", "Search brand, product, or batch code"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Label(AppStrings.text("添加", "Add"), systemImage: "plus")
                    }
                    .accessibilityIdentifier("addProductButton")
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                ProductEditorView()
            }
        }
    }

    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = filteredProducts[index]
            NotificationScheduler.shared.cancelReminder(for: product)
            modelContext.delete(product)
        }
    }
}

private struct CategoryPicker: View {
    @Binding var selectedCategory: ProductCategory?
    let products: [ProductItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: AppStrings.text("全部", "All"),
                    symbol: "square.grid.2x2",
                    count: products.count,
                    isSelected: selectedCategory == nil,
                    tint: .accentColor
                ) {
                    selectedCategory = nil
                }

                ForEach(ProductCategory.allCases) { category in
                    CategoryChip(
                        title: category.localizedTitle,
                        symbol: category.symbol,
                        count: products.filter { $0.category == category }.count,
                        isSelected: selectedCategory == category,
                        tint: category.tint
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CategoryChip: View {
    let title: String
    let symbol: String
    let count: Int
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text("\(title) \(count)")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: symbol)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? tint.opacity(0.18) : Color.secondary.opacity(0.10))
            .foregroundStyle(isSelected ? tint : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ProductRow: View {
    let product: ProductItem

    var body: some View {
        HStack(spacing: 12) {
            ProductArtworkView(product: product, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(product.brand.isEmpty ? product.category.localizedTitle : product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let secondaryName = product.secondaryDisplayName {
                    Text(secondaryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let inventoryIdentifierText = product.inventoryIdentifierText {
                    Text(inventoryIdentifierText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Label(product.status.localizedTitle, systemImage: product.status.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(product.status.tint)
                    .labelStyle(.titleAndIcon)
                Text(product.expiryDate?.shelfFormatted ?? AppStrings.text("待补全", "Missing"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProductArtworkView: View {
    let product: ProductItem
    let size: CGFloat

    var body: some View {
        ProductImagePreview(imageURL: product.productImage, category: product.category, size: size)
    }
}

struct ProductImagePreview: View {
    let imageURL: URL?
    let category: ProductCategory
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(category.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var fallback: some View {
        Image(systemName: category.symbol)
            .font(.system(size: max(18, size * 0.42), weight: .medium))
            .foregroundStyle(category.tint)
            .frame(width: size, height: size)
    }
}

#Preview {
    InventoryView()
        .modelContainer(for: ProductItem.self, inMemory: true)
}
