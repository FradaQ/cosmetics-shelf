import XCTest

final class CosmeticsShelfUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainTabsOpen() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inventory"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Reminders"].tap()
        XCTAssertTrue(app.navigationBars["Use Reminders"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Batch"].tap()
        XCTAssertTrue(app.navigationBars["Batch & Shelf Life"].waitForExistence(timeout: 3))
    }

    func testAddProductFlowSavesManualProduct() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["addProductButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Product"].waitForExistence(timeout: 3))

        let englishNameField = app.textFields["englishNameField"]
        XCTAssertTrue(englishNameField.waitForExistence(timeout: 3))
        englishNameField.tap()
        englishNameField.typeText("UI Test Serum")

        let brandField = app.textFields["brandField"]
        brandField.tap()
        brandField.typeText("Codex Beauty")

        app.buttons["saveProductButton"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Serum"].waitForExistence(timeout: 5))
    }

    func testBatchLookupPageHasSearchControls() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Batch"].tap()
        XCTAssertTrue(app.textFields["batchLookupBrandField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["batchLookupCodeField"].exists)
        XCTAssertTrue(app.buttons["batchLookupSearchButton"].exists)
    }

    func testProductLookupSheetOpensFromEditor() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["addProductButton"].tap()
        XCTAssertTrue(app.buttons["findProductInfoButton"].waitForExistence(timeout: 3))
        app.buttons["findProductInfoButton"].tap()

        XCTAssertTrue(app.navigationBars["Find Product Info"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["productLookupQueryField"].exists)
        XCTAssertTrue(app.buttons["productLookupSearchButton"].exists)
    }
}

