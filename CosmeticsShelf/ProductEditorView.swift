import SwiftData
import SwiftUI

struct ProductEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    var product: ProductItem?

    @State private var name = ""
    @State private var localName = ""
    @State private var englishName = ""
    @State private var brand = ""
    @State private var productImageURL = ""
    @State private var officialProductURL = ""
    @State private var category: ProductCategory = .skincare
    @State private var batchCode = ""
    @State private var purchaseDate = Date()
    @State private var hasManufactureDate = false
    @State private var manufactureDate = Date()
    @State private var hasOpenedDate = false
    @State private var openedDate = Date()
    @State private var hasManualExpiryDate = false
    @State private var manualExpiryDate = Date()
    @State private var unopenedShelfLifeMonths = 36
    @State private var periodAfterOpeningMonths = 12
    @State private var notes = ""
    @State private var isShowingProductLookup = false
    @State private var batchLookupMessage: String?
    @State private var batchExternalLookup: SuggestedExternalLookup?

    private var canSave: Bool {
        !primaryProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var primaryProductName: String {
        let preferred = AppLanguage.isChinese ? localName : englishName
        let fallback = AppLanguage.isChinese ? englishName : localName
        return [preferred, fallback, name].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppStrings.text("产品", "Product")) {
                    Button {
                        isShowingProductLookup = true
                    } label: {
                        Label(AppStrings.text("自动查找产品资料", "Find Product Info Automatically"), systemImage: "sparkle.magnifyingglass")
                    }
                    .accessibilityIdentifier("findProductInfoButton")

                    TextField(AppStrings.text("本地名称/中文名", "Local name"), text: $localName)
                        .accessibilityIdentifier("localNameField")
                    TextField(AppStrings.text("英文/官方名称", "English or official name"), text: $englishName)
                        .accessibilityIdentifier("englishNameField")
                    TextField(AppStrings.text("品牌", "Brand"), text: $brand)
                        .accessibilityIdentifier("brandField")
                    Picker(AppStrings.text("品类", "Category"), selection: $category) {
                        ForEach(ProductCategory.allCases) { category in
                            Label(category.localizedTitle, systemImage: category.symbol)
                                .tag(category)
                        }
                    }
                    TextField(AppStrings.text("批号", "Batch code"), text: $batchCode)
                        .textInputAutocapitalization(.characters)
                        .accessibilityIdentifier("batchCodeField")

                    Button {
                        Task { await lookupBatchCode() }
                    } label: {
                        Label(AppStrings.text("用批号自动查生产日期", "Look Up Dates from Batch Code"), systemImage: "number.square")
                    }
                    .accessibilityIdentifier("lookupBatchCodeButton")
                    .disabled(brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || batchCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let batchLookupMessage {
                        Text(batchLookupMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let batchExternalLookup {
                        Button {
                            openURL(batchExternalLookup.url)
                        } label: {
                            Label(
                                AppStrings.text(
                                    "去 \(batchExternalLookup.name) 查询",
                                    "Check on \(batchExternalLookup.name)"
                                ),
                                systemImage: "safari"
                            )
                        }
                        .accessibilityIdentifier("batchExternalLookupButton")

                        Text(batchExternalLookup.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField(AppStrings.text("官网图片链接", "Official image URL"), text: $productImageURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("productImageURLField")
                    TextField(AppStrings.text("官网产品页链接", "Official product page URL"), text: $officialProductURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("officialProductURLField")
                    ProductImagePreview(imageURL: URL(string: productImageURL), category: category)
                } header: {
                    Text(AppStrings.text("官网资料", "Official product info"))
                } footer: {
                    Text(AppStrings.text("先粘贴官网图片或产品页链接。之后可以接一个自动搜索候选图的服务。", "Paste an official image or product page URL for now. A search-and-pick flow can be added next."))
                }

                Section(AppStrings.text("日期", "Dates")) {
                    DatePicker(AppStrings.text("购买日期", "Purchase date"), selection: $purchaseDate, displayedComponents: .date)

                    Toggle(AppStrings.text("有生产日期", "Has manufacture date"), isOn: $hasManufactureDate)
                    if hasManufactureDate {
                        DatePicker(AppStrings.text("生产日期", "Manufacture date"), selection: $manufactureDate, displayedComponents: .date)
                    }

                    Toggle(AppStrings.text("已开封", "Opened"), isOn: $hasOpenedDate)
                    if hasOpenedDate {
                        DatePicker(AppStrings.text("开封日期", "Opened date"), selection: $openedDate, displayedComponents: .date)
                    }

                    Toggle(AppStrings.text("手动到期日", "Manual expiry date"), isOn: $hasManualExpiryDate)
                    if hasManualExpiryDate {
                        DatePicker(AppStrings.text("到期日", "Expiry date"), selection: $manualExpiryDate, displayedComponents: .date)
                    }
                }

                Section {
                    Stepper(AppStrings.text("未开封 \(unopenedShelfLifeMonths) 个月", "Unopened \(unopenedShelfLifeMonths) months"), value: $unopenedShelfLifeMonths, in: 6...84, step: 6)
                    Stepper(AppStrings.text("开封后 \(periodAfterOpeningMonths) 个月", "After opening \(periodAfterOpeningMonths) months"), value: $periodAfterOpeningMonths, in: 3...48, step: 3)
                } header: {
                    Text(AppStrings.text("保质期规则", "Shelf life rules"))
                } footer: {
                    Text(AppStrings.text("App 会取手动到期日、生产日期推算、开封后期限中最早的日期，并在到期前半年提醒。", "The app uses the earliest date from manual expiry, manufacture-date estimate, and period after opening, then reminds you 6 months before expiry."))
                }

                Section(AppStrings.text("备注", "Notes")) {
                    TextField(AppStrings.text("购买渠道、色号、质地或使用感", "Retailer, shade, texture, or impressions"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(product == nil ? AppStrings.text("添加产品", "Add Product") : AppStrings.text("编辑产品", "Edit Product"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.text("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.text("保存", "Save"), action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveProductButton")
                }
            }
            .onAppear(perform: seedForm)
            .sheet(isPresented: $isShowingProductLookup) {
                ProductInfoLookupSheet(
                    localName: $localName,
                    englishName: $englishName,
                    brand: $brand,
                    productImageURL: $productImageURL,
                    officialProductURL: $officialProductURL,
                    category: $category
                )
            }
        }
    }

    private func seedForm() {
        guard let product else { return }
        name = product.name
        localName = product.localName
        englishName = product.englishName
        brand = product.brand
        productImageURL = product.productImageURL
        officialProductURL = product.officialProductURL
        category = product.category
        batchCode = product.batchCode
        purchaseDate = product.purchaseDate
        if let date = product.manufactureDate {
            hasManufactureDate = true
            manufactureDate = date
        }
        if let date = product.openedDate {
            hasOpenedDate = true
            openedDate = date
        }
        if let date = product.manualExpiryDate {
            hasManualExpiryDate = true
            manualExpiryDate = date
        }
        unopenedShelfLifeMonths = product.unopenedShelfLifeMonths
        periodAfterOpeningMonths = product.periodAfterOpeningMonths
        notes = product.notes
    }

    private func save() {
        let trimmedLocalName = localName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnglishName = englishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = primaryProductName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBatch = batchCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedImageURL = productImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOfficialURL = officialProductURL.trimmingCharacters(in: .whitespacesAndNewlines)

        let item = product ?? ProductItem(name: trimmedName, brand: trimmedBrand, category: category)
        item.name = trimmedName
        item.localName = trimmedLocalName
        item.englishName = trimmedEnglishName
        item.brand = trimmedBrand
        item.productImageURL = trimmedImageURL
        item.officialProductURL = trimmedOfficialURL
        item.category = category
        item.batchCode = trimmedBatch
        item.purchaseDate = purchaseDate
        item.manufactureDate = hasManufactureDate ? manufactureDate : nil
        item.openedDate = hasOpenedDate ? openedDate : nil
        item.manualExpiryDate = hasManualExpiryDate ? manualExpiryDate : nil
        item.unopenedShelfLifeMonths = unopenedShelfLifeMonths
        item.periodAfterOpeningMonths = periodAfterOpeningMonths
        item.notes = notes

        if product == nil {
            modelContext.insert(item)
        }

        NotificationScheduler.shared.scheduleReminder(for: item)
        dismiss()
    }

    private func lookupBatchCode() async {
        let service = ProductLookupService()
        let result = await service.lookupBatchCode(brand: brand, batchCode: batchCode, category: category)

        guard let result else {
            batchLookupMessage = AppStrings.text(
                "没有找到可靠的批号解析结果，请手动输入生产日期或到期日。",
                "No reliable batch-code result found. Enter manufacture or expiry dates manually."
            )
            batchExternalLookup = nil
            return
        }

        if let manufactureDate = result.manufactureDate {
            self.manufactureDate = manufactureDate
            hasManufactureDate = true
        }

        if let expiryDate = result.expiryDate {
            manualExpiryDate = expiryDate
            hasManualExpiryDate = true
        }

        batchExternalLookup = result.suggestedExternalLookup
        batchLookupMessage = result.message ?? result.sourceDescription
    }
}

#Preview {
    ProductEditorView()
        .modelContainer(for: ProductItem.self, inMemory: true)
}
