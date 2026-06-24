import Foundation

struct ProductSearchCandidate: Identifiable, Hashable {
    let id: String
    let productName: String
    let englishName: String
    let brand: String
    let imageURL: URL?
    let sourceURL: URL?

    var displayName: String {
        let preferred = AppLanguage.isChinese ? productName : englishName
        return [preferred, englishName, productName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? AppStrings.text("未命名产品", "Unnamed product")
    }
}

struct BatchCodeLookupResult {
    let manufactureDate: Date?
    let expiryDate: Date?
    let sourceDescription: String
}

enum LookupError: LocalizedError {
    case emptyQuery
    case noResults

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            AppStrings.text("请输入产品名称。", "Enter a product name.")
        case .noResults:
            AppStrings.text("没有找到可用候选。", "No usable candidates found.")
        }
    }
}

struct ProductLookupService {
    func searchProducts(query: String) async throws -> [ProductSearchCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw LookupError.emptyQuery }

        var components = URLComponents(string: "https://world.openbeautyfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmedQuery),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "12"),
            URLQueryItem(name: "fields", value: "code,product_name,product_name_en,brands,image_front_url,image_url,url")
        ]

        guard let url = components?.url else { throw LookupError.emptyQuery }

        var request = URLRequest(url: url)
        request.setValue("CosmeticsShelf/1.0 (personal prototype)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenBeautyFactsSearchResponse.self, from: data)
        let candidates = response.products.compactMap(ProductSearchCandidate.init)

        if candidates.isEmpty {
            throw LookupError.noResults
        }

        return candidates
    }

    func lookupBatchCode(brand: String, batchCode: String) async -> BatchCodeLookupResult? {
        nil
    }
}

private struct OpenBeautyFactsSearchResponse: Decodable {
    let products: [OpenBeautyFactsProduct]
}

private struct OpenBeautyFactsProduct: Decodable {
    let code: String?
    let productName: String?
    let productNameEnglish: String?
    let brands: String?
    let imageFrontURL: String?
    let imageURL: String?
    let sourceURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEnglish = "product_name_en"
        case brands
        case imageFrontURL = "image_front_url"
        case imageURL = "image_url"
        case sourceURL = "url"
    }
}

private extension ProductSearchCandidate {
    init?(product: OpenBeautyFactsProduct) {
        let localName = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let englishName = product.productNameEnglish?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let imageURLString = product.imageFrontURL ?? product.imageURL ?? ""

        guard !localName.isEmpty || !englishName.isEmpty else {
            return nil
        }

        self.id = product.code ?? UUID().uuidString
        self.productName = localName
        self.englishName = englishName
        self.brand = brand
        self.imageURL = URL(string: imageURLString)
        self.sourceURL = URL(string: product.sourceURL ?? "")
    }
}

