import Foundation

struct ProductSearchCandidate: Identifiable, Hashable {
    let id: String
    let productName: String
    let englishName: String
    let brand: String
    let category: ProductCategory?
    let imageURL: URL?
    let sourceURL: URL?
    let source: LookupSource
    let confidence: LookupConfidence
    let matchReasons: [String]

    var displayName: String {
        let preferred = AppLanguage.isChinese ? productName : englishName
        return [preferred, englishName, productName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? AppStrings.text("未命名产品", "Unnamed product")
    }
}

enum LookupSource: String, Codable, Hashable {
    case officialWebsite
    case openBeautyFacts
    case localBatchRule
    case manual

    var localizedTitle: String {
        switch self {
        case .officialWebsite:
            AppStrings.text("官网", "Official")
        case .openBeautyFacts:
            "Open Beauty Facts"
        case .localBatchRule:
            AppStrings.text("本地规则", "Local rule")
        case .manual:
            AppStrings.text("手动", "Manual")
        }
    }
}

enum LookupConfidence: String, Codable, Hashable, Comparable {
    case high
    case medium
    case low

    static func < (lhs: LookupConfidence, rhs: LookupConfidence) -> Bool {
        lhs.sortValue < rhs.sortValue
    }

    private var sortValue: Int {
        switch self {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    var localizedTitle: String {
        switch self {
        case .high:
            AppStrings.text("高可信", "High")
        case .medium:
            AppStrings.text("中可信", "Medium")
        case .low:
            AppStrings.text("低可信", "Low")
        }
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
    private let apiBaseURL: URL?
    private let urlSession: URLSession

    init(
        apiBaseURL: URL? = ProductLookupService.defaultAPIBaseURL,
        urlSession: URLSession = .shared
    ) {
        self.apiBaseURL = apiBaseURL
        self.urlSession = urlSession
    }

    func searchProducts(query: String, brand: String = "", barcode: String = "") async throws -> [ProductSearchCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty || !trimmedBarcode.isEmpty else { throw LookupError.emptyQuery }

        if let apiBaseURL {
            do {
                let candidates = try await searchProductsFromAPI(
                    baseURL: apiBaseURL,
                    query: trimmedQuery,
                    brand: brand,
                    barcode: trimmedBarcode
                )
                if !candidates.isEmpty {
                    return candidates
                }
            } catch {
                // Keep lookup useful while the local API is offline or still being developed.
            }
        }

        guard !trimmedQuery.isEmpty else { throw LookupError.noResults }

        return try await searchProductsFromOpenBeautyFacts(query: trimmedQuery, brand: brand)
    }

    func lookupBatchCode(brand: String, batchCode: String, category: ProductCategory = .other) async -> BatchCodeLookupResult? {
        guard let apiBaseURL else { return nil }

        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBatchCode = batchCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBrand.isEmpty, !trimmedBatchCode.isEmpty else { return nil }

        do {
            let url = apiBaseURL.appending(path: "v1/batch-lookup")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 8
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONEncoder().encode(
                APIBatchLookupRequest(
                    brand: trimmedBrand,
                    batchCode: trimmedBatchCode,
                    category: category.apiValue
                )
            )

            let (data, response) = try await urlSession.data(for: request)
            try validate(response: response)

            let lookup = try JSONDecoder().decode(APIBatchLookupResponse.self, from: data)
            guard lookup.result == "found" else { return nil }

            return BatchCodeLookupResult(
                manufactureDate: lookup.manufactureDate.flatMap(Self.dateFormatter.date(from:)),
                expiryDate: lookup.expiryDate.flatMap(Self.dateFormatter.date(from:)),
                sourceDescription: lookup.sourceDescription
            )
        } catch {
            return nil
        }
    }

    private func searchProductsFromAPI(
        baseURL: URL,
        query: String,
        brand: String,
        barcode: String
    ) async throws -> [ProductSearchCandidate] {
        let url = baseURL.appending(path: "v1/product-lookup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            APIProductLookupRequest(
                query: query,
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                barcode: barcode,
                locale: Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
                preferredLanguage: Locale.preferredLanguages.first?
                    .split(separator: "-")
                    .first
                    .map(String.init) ?? "en"
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response)

        let lookup = try JSONDecoder().decode(APIProductLookupResponse.self, from: data)
        return lookup.candidates
            .compactMap(ProductSearchCandidate.init(apiCandidate:))
            .sortedForLookup()
    }

    private func searchProductsFromOpenBeautyFacts(query: String, brand: String) async throws -> [ProductSearchCandidate] {
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = [trimmedBrand, query]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")

        var components = URLComponents(string: "https://world.openbeautyfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: searchTerms),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "12"),
            URLQueryItem(name: "fields", value: "code,product_name,product_name_en,brands,image_front_url,image_url,url")
        ]

        guard let url = components?.url else { throw LookupError.emptyQuery }

        var request = URLRequest(url: url)
        request.setValue("CosmeticsShelf/1.0 (personal prototype)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response)

        let searchResponse = try JSONDecoder().decode(OpenBeautyFactsSearchResponse.self, from: data)
        var candidates = searchResponse.products
            .compactMap { ProductSearchCandidate(product: $0, query: query) }
            .sortedForLookup()

        if !trimmedBrand.isEmpty {
            candidates = candidates.filter { $0.brand.matchesBrand(trimmedBrand) }
        }

        if candidates.isEmpty {
            throw LookupError.noResults
        }

        return candidates
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LookupError.noResults
        }
    }

    static func guessCategory(from text: String) -> ProductCategory? {
        let value = text.lowercased()

        let fragranceTerms = ["perfume", "parfum", "eau de", "fragrance", "cologne", "香水"]
        if fragranceTerms.contains(where: value.contains) {
            return .fragrance
        }

        let makeupTerms = ["lipstick", "mascara", "foundation", "concealer", "blush", "eyeshadow", "palette", "口红", "粉底", "腮红", "眼影"]
        if makeupTerms.contains(where: value.contains) {
            return .makeup
        }

        let hairBodyTerms = ["shampoo", "conditioner", "body wash", "hand cream", "body lotion", "hair", "洗发", "护发", "身体乳", "沐浴"]
        if hairBodyTerms.contains(where: value.contains) {
            return .hairBody
        }

        let skincareTerms = ["serum", "cream", "cleanser", "toner", "essence", "moisturizer", "sunscreen", "mask", "retinol", "精华", "面霜", "洁面", "爽肤", "防晒", "面膜"]
        if skincareTerms.contains(where: value.contains) {
            return .skincare
        }

        return nil
    }

    private static var defaultAPIBaseURL: URL? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CosmeticsShelfAPIBaseURL") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }

        return URL(string: "http://127.0.0.1:8000")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct OpenBeautyFactsSearchResponse: Decodable {
    let products: [OpenBeautyFactsProduct]
}

private struct APIProductLookupRequest: Encodable {
    let query: String
    let brand: String
    let barcode: String
    let locale: String
    let preferredLanguage: String
}

private struct APIProductLookupResponse: Decodable {
    let candidates: [APIProductCandidate]
}

private struct APIProductCandidate: Decodable {
    let id: String
    let localName: String
    let englishName: String
    let brand: String
    let category: String
    let imageURL: URL?
    let productPageURL: URL?
    let source: LookupSource
    let confidence: LookupConfidence
    let matchReasons: [String]
}

private struct APIBatchLookupRequest: Encodable {
    let brand: String
    let batchCode: String
    let category: String
}

private struct APIBatchLookupResponse: Decodable {
    let result: String
    let manufactureDate: String?
    let expiryDate: String?
    let sourceDescription: String
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
    init?(apiCandidate: APIProductCandidate) {
        let localName = apiCandidate.localName.trimmingCharacters(in: .whitespacesAndNewlines)
        let englishName = apiCandidate.englishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = apiCandidate.brand.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !localName.isEmpty || !englishName.isEmpty else {
            return nil
        }

        self.id = apiCandidate.id
        self.productName = localName
        self.englishName = englishName
        self.brand = brand
        self.category = ProductCategory(apiValue: apiCandidate.category)
        self.imageURL = apiCandidate.imageURL
        self.sourceURL = apiCandidate.productPageURL
        self.source = apiCandidate.source
        self.confidence = apiCandidate.confidence
        self.matchReasons = apiCandidate.matchReasons
    }

    init?(product: OpenBeautyFactsProduct, query: String) {
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
        self.category = ProductLookupService.guessCategory(from: [localName, englishName].joined(separator: " "))
        self.imageURL = URL(string: imageURLString)
        self.sourceURL = URL(string: product.sourceURL ?? "")
        self.source = .openBeautyFacts

        let ranking = ProductLookupRanking.evaluate(
            query: query,
            productName: localName,
            englishName: englishName,
            brand: brand,
            imageURLString: imageURLString,
            sourceURLString: product.sourceURL ?? ""
        )
        self.confidence = ranking.confidence
        self.matchReasons = ranking.reasons
    }
}

private extension ProductCategory {
    init?(apiValue: String) {
        switch apiValue {
        case "skincare":
            self = .skincare
        case "makeup":
            self = .makeup
        case "fragrance":
            self = .fragrance
        case "hairBody":
            self = .hairBody
        case "unknown":
            return nil
        default:
            return nil
        }
    }

    var apiValue: String {
        switch self {
        case .skincare:
            "skincare"
        case .makeup:
            "makeup"
        case .fragrance:
            "fragrance"
        case .hairBody:
            "hairBody"
        case .other:
            "unknown"
        }
    }
}

private struct ProductLookupRanking {
    let score: Int
    let confidence: LookupConfidence
    let reasons: [String]

    static func evaluate(
        query: String,
        productName: String,
        englishName: String,
        brand: String,
        imageURLString: String,
        sourceURLString: String
    ) -> ProductLookupRanking {
        let normalizedQuery = query.normalizedForLookup
        let normalizedName = [productName, englishName].joined(separator: " ").normalizedForLookup
        let normalizedBrand = brand.normalizedForLookup
        var score = 0
        var reasons: [String] = []

        if !normalizedBrand.isEmpty, normalizedQuery.contains(normalizedBrand) {
            score += 35
            reasons.append(AppStrings.text("品牌匹配", "Brand match"))
        }

        if !normalizedName.isEmpty {
            if normalizedName.contains(normalizedQuery) || normalizedQuery.contains(normalizedName) {
                score += 35
                reasons.append(AppStrings.text("名称高度匹配", "Strong name match"))
            } else {
                let queryTokens = Set(normalizedQuery.split(separator: " ").map(String.init))
                let nameTokens = Set(normalizedName.split(separator: " ").map(String.init))
                let overlap = queryTokens.intersection(nameTokens).count
                if overlap >= 2 {
                    score += 25
                    reasons.append(AppStrings.text("名称关键词匹配", "Name keyword match"))
                } else if overlap == 1 {
                    score += 10
                    reasons.append(AppStrings.text("部分关键词匹配", "Partial keyword match"))
                }
            }
        }

        if !imageURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 15
            reasons.append(AppStrings.text("有产品图片", "Has product image"))
        }

        if !sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 10
            reasons.append(AppStrings.text("有来源页面", "Has source page"))
        }

        if normalizedBrand.isEmpty {
            score -= 20
        }

        let confidence: LookupConfidence
        if score >= 70 {
            confidence = .high
        } else if score >= 35 {
            confidence = .medium
        } else {
            confidence = .low
        }

        return ProductLookupRanking(score: score, confidence: confidence, reasons: reasons)
    }
}

private extension Array where Element == ProductSearchCandidate {
    func sortedForLookup() -> [ProductSearchCandidate] {
        sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }

            if (lhs.imageURL != nil) != (rhs.imageURL != nil) {
                return lhs.imageURL != nil
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private extension String {
    var normalizedForLookup: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\p{Han}]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedBrandForLookup: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\p{Han}]+", with: "", options: .regularExpression)
    }

    func matchesBrand(_ requestedBrand: String) -> Bool {
        let requested = requestedBrand.normalizedBrandForLookup
        let candidate = normalizedBrandForLookup
        guard !requested.isEmpty, !candidate.isEmpty else { return false }
        return requested == candidate || requested.contains(candidate) || candidate.contains(requested)
    }
}
