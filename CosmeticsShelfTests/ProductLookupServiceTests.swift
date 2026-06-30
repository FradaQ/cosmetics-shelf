import XCTest
@testable import CosmeticsShelf

final class ProductLookupServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testBatchCodeLookupFallsBackToManualEntryWhenAPIIsDisabled() async {
        let service = ProductLookupService(apiBaseURL: nil)
        let result = await service.lookupBatchCode(brand: "Example", batchCode: "A12")

        XCTAssertNil(result)
    }

    func testBatchCodeLookupDecodesExternalSuggestionWhenNoResult() async throws {
        let session = URLSession(configuration: .mocked)
        let service = ProductLookupService(
            apiBaseURL: try XCTUnwrap(URL(string: "http://example.test")),
            urlSession: session
        )

        MockURLProtocol.requestHandler = { request in
            let body = try requestBodyData(from: request)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

            XCTAssertEqual(json?["brand"] as? String, "Tatcha")
            XCTAssertEqual(json?["batchCode"] as? String, "ABC123")
            XCTAssertEqual(json?["category"] as? String, "skincare")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let data = Data("""
            {
              "result": "no_result",
              "manufactureDate": null,
              "expiryDate": null,
              "confidence": null,
              "source": "unsupported",
              "sourceDescription": "No reliable brand-specific batch-code rule is configured.",
              "message": "Use manual manufacture or expiry date entry in the app.",
              "suggestedExternalLookup": {
                "name": "CheckFresh",
                "url": "https://www.checkfresh.com/",
                "note": "External informational lookup. Verify the result before saving dates."
              }
            }
            """.utf8)
            return (response, data)
        }

        let result = await service.lookupBatchCode(
            brand: "Tatcha",
            batchCode: "ABC123",
            category: .skincare
        )

        let lookup = try XCTUnwrap(result)
        XCTAssertNil(lookup.manufactureDate)
        XCTAssertNil(lookup.expiryDate)
        XCTAssertEqual(lookup.message, "Use manual manufacture or expiry date entry in the app.")
        XCTAssertEqual(lookup.suggestedExternalLookup?.name, "CheckFresh")
        XCTAssertEqual(lookup.suggestedExternalLookup?.url.absoluteString, "https://www.checkfresh.com/")
    }

    func testGuessCategoryFromProductName() {
        XCTAssertEqual(ProductLookupService.guessCategory(from: "Libre Eau de Parfum"), .fragrance)
        XCTAssertEqual(ProductLookupService.guessCategory(from: "Soft Matte Lipstick"), .makeup)
        XCTAssertEqual(ProductLookupService.guessCategory(from: "Repair Shampoo"), .hairBody)
        XCTAssertEqual(ProductLookupService.guessCategory(from: "Advanced Night Repair Serum"), .skincare)
    }

    func testLookupConfidenceOrdering() {
        XCTAssertGreaterThan(LookupConfidence.high, .medium)
        XCTAssertGreaterThan(LookupConfidence.medium, .low)
    }

    func testProductLookupSendsRetailerFallbackFieldsAndDecodesAuthorizedRetailer() async throws {
        let session = URLSession(configuration: .mocked)
        let service = ProductLookupService(
            apiBaseURL: try XCTUnwrap(URL(string: "http://example.test")),
            urlSession: session
        )

        MockURLProtocol.requestHandler = { request in
            let body = try requestBodyData(from: request)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

            XCTAssertEqual(json?["query"] as? String, "Lancome Genifique serum")
            XCTAssertEqual(json?["brand"] as? String, "Lancome")
            XCTAssertEqual(json?["allowRetailerFallback"] as? Bool, true)
            XCTAssertEqual(json?["preferredRetailers"] as? [String], ["sephora"])
            XCTAssertEqual(json?["retailerProductPageURL"] as? String, "https://www.sephora.com/product/example")
            XCTAssertEqual(json?["retailerImageURL"] as? String, "https://www.sephora.com/productimages/example.jpg")
            XCTAssertEqual(json?["retailerProductName"] as? String, "Advanced Genifique Face Serum")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let data = Data("""
            {
              "candidates": [
                {
                  "id": "sephora-lancome-genifique",
                  "localName": "Advanced Genifique Face Serum",
                  "englishName": "Advanced Genifique Face Serum",
                  "brand": "Lancome",
                  "category": "skincare",
                  "imageURL": "https://www.sephora.com/productimages/example.jpg",
                  "productPageURL": "https://www.sephora.com/product/example",
                  "source": "authorizedRetailer",
                  "confidence": "high",
                  "matchReasons": ["retailer fallback"]
                }
              ]
            }
            """.utf8)
            return (response, data)
        }

        let candidates = try await service.searchProducts(
            query: "Lancome Genifique serum",
            brand: "Lancome",
            allowRetailerFallback: true,
            preferredRetailers: ["sephora"],
            retailerProductPageURL: "https://www.sephora.com/product/example",
            retailerImageURL: "https://www.sephora.com/productimages/example.jpg",
            retailerProductName: "Advanced Genifique Face Serum"
        )

        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidate.source, .authorizedRetailer)
        XCTAssertEqual(candidate.confidence, .high)
    }
}

private extension URLSessionConfiguration {
    static var mocked: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: LookupTestError.missingRequestHandler)
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum LookupTestError: Error {
    case missingRequestHandler
    case missingRequestBody
}

private func requestBodyData(from request: URLRequest) throws -> Data {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let stream = request.httpBodyStream else {
        throw LookupTestError.missingRequestBody
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 {
            throw stream.streamError ?? LookupTestError.missingRequestBody
        }
        if count == 0 {
            break
        }
        data.append(buffer, count: count)
    }
    return data
}
