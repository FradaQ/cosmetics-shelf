import SwiftUI

struct ProductInfoLookupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Binding var localName: String
    @Binding var englishName: String
    @Binding var brand: String
    @Binding var productImageURL: String
    @Binding var officialProductURL: String
    @Binding var category: ProductCategory

    @State private var query: String
    @State private var lookupBrand: String
    @State private var candidates: [ProductSearchCandidate] = []
    @State private var selectedCandidate: ProductSearchCandidate?
    @State private var shouldReplaceExistingFields = false
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let service = ProductLookupService()

    init(
        localName: Binding<String>,
        englishName: Binding<String>,
        brand: Binding<String>,
        productImageURL: Binding<String>,
        officialProductURL: Binding<String>,
        category: Binding<ProductCategory>
    ) {
        self._localName = localName
        self._englishName = englishName
        self._brand = brand
        self._productImageURL = productImageURL
        self._officialProductURL = officialProductURL
        self._category = category
        self._query = State(initialValue: [brand.wrappedValue, englishName.wrappedValue, localName.wrappedValue]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " "))
        self._lookupBrand = State(initialValue: brand.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(AppStrings.text("品牌", "Brand"), text: $lookupBrand)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("productLookupBrandField")

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
                    Text(AppStrings.text("会优先查询公开美妆产品数据库，并用来源和可信度标记候选。若没有准确结果，可以继续手动输入官网链接。", "Searches a public beauty product database first and labels candidates by source and confidence. If nothing is accurate, continue with manual official links."))
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
                                selectedCandidate = candidate
                            } label: {
                                ProductCandidateRow(candidate: candidate, isSelected: selectedCandidate?.id == candidate.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let selectedCandidate {
                    Section {
                        ProductLookupPreview(candidate: selectedCandidate)

                        Toggle(AppStrings.text("覆盖已有字段", "Replace existing fields"), isOn: $shouldReplaceExistingFields)

                        Button {
                            apply(selectedCandidate)
                        } label: {
                            Label(AppStrings.text("应用这个候选", "Apply This Candidate"), systemImage: "checkmark.circle.fill")
                        }
                        .accessibilityIdentifier("applyProductCandidateButton")
                    } header: {
                        Text(AppStrings.text("预览更改", "Preview Changes"))
                    } footer: {
                        Text(AppStrings.text("默认只填写空字段。打开覆盖后，会用这个候选替换已经填写过的名称、品牌、图片和官网链接。", "By default, only empty fields are filled. Turn on replace to overwrite existing names, brand, image, and source URL."))
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
        selectedCandidate = nil

        do {
            candidates = try await service.searchProducts(query: searchQuery)
        } catch {
            candidates = []
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func apply(_ candidate: ProductSearchCandidate) {
        apply(candidate.productName, to: &localName)
        apply(candidate.englishName, to: &englishName)
        apply(candidate.brand, to: &brand)
        if let candidateCategory = candidate.category {
            category = candidateCategory
        }
        apply(candidate.imageURL?.absoluteString ?? "", to: &productImageURL)
        apply(candidate.sourceURL?.absoluteString ?? "", to: &officialProductURL)
        dismiss()
    }

    private func apply(_ newValue: String, to field: inout String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if shouldReplaceExistingFields || field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            field = trimmed
        }
    }

    private func openOfficialSearch() {
        let searchText = [lookupBrand, query, "official product"]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
        let encoded = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            openURL(url)
        }
    }

    private var searchQuery: String {
        [lookupBrand, query]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
    }
}

private struct ProductCandidateRow: View {
    let candidate: ProductSearchCandidate
    let isSelected: Bool

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
            .frame(width: 56, height: 56)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.displayName)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !candidate.brand.isEmpty {
                        Text(candidate.brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let category = candidate.category {
                        Label(category.localizedTitle, systemImage: category.symbol)
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    LookupBadge(text: candidate.source.localizedTitle, tint: .teal)
                    LookupBadge(text: candidate.confidence.localizedTitle, tint: candidate.confidence.tint)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProductLookupPreview: View {
    let candidate: ProductSearchCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PreviewRow(title: AppStrings.text("显示名称", "Display name"), value: candidate.displayName)
            if !candidate.englishName.isEmpty {
                PreviewRow(title: AppStrings.text("英文/官方名", "English/official"), value: candidate.englishName)
            }
            if !candidate.brand.isEmpty {
                PreviewRow(title: AppStrings.text("品牌", "Brand"), value: candidate.brand)
            }
            if let category = candidate.category {
                PreviewRow(title: AppStrings.text("品类", "Category"), value: category.localizedTitle)
            }
            if let imageURL = candidate.imageURL {
                PreviewRow(title: AppStrings.text("图片", "Image"), value: imageURL.host() ?? imageURL.absoluteString)
            }
            if let sourceURL = candidate.sourceURL {
                PreviewRow(title: AppStrings.text("来源", "Source"), value: sourceURL.host() ?? sourceURL.absoluteString)
            }
            if !candidate.matchReasons.isEmpty {
                PreviewRow(title: AppStrings.text("匹配原因", "Match"), value: candidate.matchReasons.joined(separator: ", "))
            }
        }
        .font(.subheadline)
    }
}

private struct PreviewRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LookupBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private extension LookupConfidence {
    var tint: Color {
        switch self {
        case .high: .green
        case .medium: .orange
        case .low: .secondary
        }
    }
}
