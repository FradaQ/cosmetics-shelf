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
    case noOfficialResults

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            AppStrings.text("请输入产品名称。", "Enter a product name.")
        case .noResults:
            AppStrings.text("没有找到可用候选。", "No usable candidates found.")
        case .noOfficialResults:
            AppStrings.text(
                "没有找到官网候选，请手动输入产品信息或添加官网链接。",
                "No official candidate found. Enter product info manually or add an official product link."
            )
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

    func searchProducts(
        query: String,
        brand: String = "",
        barcode: String = "",
        officialProductPageURL: String = "",
        officialImageURL: String = "",
        officialName: String = ""
    ) async throws -> [ProductSearchCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty || !trimmedBarcode.isEmpty else { throw LookupError.emptyQuery }
        guard let apiBaseURL else { throw LookupError.noOfficialResults }

        let candidates = try await searchProductsFromAPI(
            baseURL: apiBaseURL,
            query: trimmedQuery,
            brand: brand,
            barcode: trimmedBarcode,
            officialProductPageURL: officialProductPageURL,
            officialImageURL: officialImageURL,
            officialName: officialName
        )
        guard !candidates.isEmpty else { throw LookupError.noOfficialResults }
        return candidates
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
        barcode: String,
        officialProductPageURL: String,
        officialImageURL: String,
        officialName: String
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
                    .map(String.init) ?? "en",
                officialProductPageURL: officialProductPageURL.nilIfBlank,
                officialImageURL: officialImageURL.nilIfBlank,
                officialName: officialName.nilIfBlank
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response)

        let lookup = try JSONDecoder().decode(APIProductLookupResponse.self, from: data)
        return lookup.candidates
            .compactMap(ProductSearchCandidate.init(apiCandidate:))
            .sortedForLookup()
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

private struct APIProductLookupRequest: Encodable {
    let query: String
    let brand: String
    let barcode: String
    let locale: String
    let preferredLanguage: String
    let officialProductPageURL: String?
    let officialImageURL: String?
    let officialName: String?
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
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
