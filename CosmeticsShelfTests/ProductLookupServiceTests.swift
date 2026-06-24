import XCTest
@testable import CosmeticsShelf

final class ProductLookupServiceTests: XCTestCase {
    func testBatchCodeLookupCurrentlyFallsBackToManualEntry() async {
        let service = ProductLookupService()
        let result = await service.lookupBatchCode(brand: "Example", batchCode: "A12")

        XCTAssertNil(result)
    }
}

