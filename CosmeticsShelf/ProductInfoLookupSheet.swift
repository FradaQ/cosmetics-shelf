import SwiftUI

struct ProductInfoLookupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Binding var localName: String
    @Binding var englishName: String
    @Binding var brand: String
    @Binding var productImageURL: String
    @Binding var officialProductURL: String

    @State private var query: String
    @State private var candidates: [ProductSearchCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let service = ProductLookupService()

    init(
        localName: Binding<String>,
        englishName: Binding<String>,
        brand: Binding<String>,
        productImageURL: Binding<String>,
        officialProductURL: Binding<String>
    ) {
        self._localName = localName
        self._englishName = englishName
        self._brand = brand
        self._productImageURL = productImageURL
        self._officialProductURL = officialProductURL
        self._query = State(initialValue: [brand.wrappedValue, englishName.wrappedValue, localName.wrappedValue]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " "))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(AppStrings.text("输入产品名称", "Enter product name"), text: $query)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("productLookupQueryField")

                    Button {
                        Task { await search() }
                    } label: {
                        Label(AppStrings.text("自动查找产品资料", "Find Product Info"), systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("productLookupSearchButton")
                    .disabled(isSearching)
                } footer: {
                    Text(AppStrings.text("会优先查询公开美妆产品数据库。若没有准确结果，可以继续手动输入官网链接。", "Searches a public beauty product database first. If nothing is accurate, continue with manual official links."))
                }

                if isSearching {
                    Section {
                        HStack {
                            ProgressView()
                            Text(AppStrings.text("正在查找…", "Searching..."))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !candidates.isEmpty {
                    Section(AppStrings.text("候选产品", "Product Candidates")) {
                        ForEach(candidates) { candidate in
                            Button {
                                apply(candidate)
                            } label: {
                                ProductCandidateRow(candidate: candidate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button {
                        openOfficialSearch()
                    } label: {
                        Label(AppStrings.text("用网页搜索官网产品页", "Search official product page on web"), systemImage: "safari")
                    }
                }
            }
            .navigationTitle(AppStrings.text("查找产品资料", "Find Product Info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.text("关闭", "Close")) {
                        dismiss()
                    }
                }
            }
            .task {
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && candidates.isEmpty {
                    await search()
                }
            }
        }
    }

    private func search() async {
        isSearching = true
        errorMessage = nil

        do {
            candidates = try await service.searchProducts(query: query)
        } catch {
            candidates = []
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func apply(_ candidate: ProductSearchCandidate) {
        localName = candidate.productName
        englishName = candidate.englishName
        if !candidate.brand.isEmpty {
            brand = candidate.brand
        }
        if let imageURL = candidate.imageURL {
            productImageURL = imageURL.absoluteString
        }
        if let sourceURL = candidate.sourceURL {
            officialProductURL = sourceURL.absoluteString
        }
        dismiss()
    }

    private func openOfficialSearch() {
        let searchText = [brand, query, "official product"]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
        let encoded = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            openURL(url)
        }
    }
}

private struct ProductCandidateRow: View {
    let candidate: ProductSearchCandidate

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: candidate.imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                @unknown default:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.displayName)
                    .font(.headline)
                    .lineLimit(2)
                if !candidate.brand.isEmpty {
                    Text(candidate.brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
