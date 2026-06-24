import XCTest
@testable import CosmeticsShelf

final class ProductLookupServiceTests: XCTestCase {
    func testBatchCodeLookupCurrentlyFallsBackToManualEntry() async {
        let service = ProductLookupService()
        let result = await service.lookupBatchCode(brand: "Example", batchCode: "A12")

        XCTAssertNil(result)
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
}
