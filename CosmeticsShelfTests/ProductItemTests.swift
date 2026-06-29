import XCTest
@testable import CosmeticsShelf

final class ProductItemTests: XCTestCase {
    func testExpiryDateUsesEarliestAvailableDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let manufactureDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)))
        let openedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 9, day: 1)))
        let manualExpiryDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))

        let product = ProductItem(
            name: "Serum",
            brand: "Example",
            category: .skincare,
            manufactureDate: manufactureDate,
            openedDate: openedDate,
            manualExpiryDate: manualExpiryDate,
            unopenedShelfLifeMonths: 36,
            periodAfterOpeningMonths: 6
        )

        let expectedExpiryDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 3, day: 1)))
        XCTAssertEqual(product.expiryDate, expectedExpiryDate)
        XCTAssertEqual(product.expiryBasis, .opened)
    }

    func testReminderStartsSixMonthsBeforeExpiry() throws {
        let calendar = Calendar(identifier: .gregorian)
        let manualExpiryDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 15)))

        let product = ProductItem(
            name: "Cream",
            brand: "Example",
            category: .skincare,
            manualExpiryDate: manualExpiryDate
        )

        let expectedReminderDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        XCTAssertEqual(product.remindFromDate, expectedReminderDate)
    }

    func testDisplayNameFallsBackToAvailableProductName() {
        let product = ProductItem(
            name: "Fallback Name",
            localName: "",
            englishName: "Official English Name",
            brand: "Example",
            category: .makeup
        )

        XCTAssertFalse(product.displayName.isEmpty)
        XCTAssertTrue(["Official English Name", "Fallback Name"].contains(product.displayName))
    }

    func testProductImageURLParsing() {
        let product = ProductItem(
            name: "Perfume",
            brand: "Example",
            productImageURL: "https://example.com/product.jpg",
            officialProductURL: "https://example.com/product",
            category: .fragrance
        )

        XCTAssertEqual(product.productImage?.absoluteString, "https://example.com/product.jpg")
        XCTAssertEqual(product.officialProduct?.absoluteString, "https://example.com/product")
    }

    func testInventoryIdentifierShowsManufactureDateAndBatchCode() throws {
        let calendar = Calendar(identifier: .gregorian)
        let manufactureDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 3, day: 14)))
        let product = ProductItem(
            name: "Cleanser",
            brand: "Example",
            category: .skincare,
            batchCode: "A12",
            manufactureDate: manufactureDate
        )

        let identifier = try XCTUnwrap(product.inventoryIdentifierText)
        XCTAssertTrue(identifier.contains("2025"))
        XCTAssertTrue(identifier.contains("A12"))
    }

    func testExpiryDisplayTextLabelsExpiryDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let manualExpiryDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 4, day: 20)))
        let product = ProductItem(
            name: "Cleanser",
            brand: "Example",
            category: .skincare,
            manualExpiryDate: manualExpiryDate
        )

        XCTAssertTrue(product.expiryDisplayText.contains("2027"))
        XCTAssertTrue(product.expiryDisplayText.contains(AppLanguage.isChinese ? "到期" : "Expires"))
    }
}
