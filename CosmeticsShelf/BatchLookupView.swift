import SwiftUI

struct BatchLookupView: View {
    @Environment(\.openURL) private var openURL
    @State private var brand = ""
    @State private var batchCode = ""
    @State private var manufactureDate = Date()
    @State private var hasManufactureDate = false
    @State private var shelfLifeMonths = 36
    @State private var openingMonths = 12
    @State private var isLookingUp = false
    @State private var lookupMessage: String?
    @State private var externalLookup: SuggestedExternalLookup?

    private var estimatedExpiryDate: Date? {
        guard hasManufactureDate else { return nil }
        return Calendar.current.date(byAdding: .month, value: shelfLifeMonths, to: manufactureDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppStrings.text("品牌", "Brand"), text: $brand)
                        .accessibilityIdentifier("batchLookupBrandField")
                    TextField(AppStrings.text("批号", "Batch code"), text: $batchCode)
                        .textInputAutocapitalization(.characters)
                        .accessibilityIdentifier("batchLookupCodeField")

                    Button {
                        Task { await lookupBatchCode() }
                    } label: {
                        Label(
                            isLookingUp
                                ? AppStrings.text("查询中...", "Looking up...")
                                : AppStrings.text("查询批号", "Look up batch code"),
                            systemImage: "magnifyingglass"
                        )
                    }
                    .accessibilityIdentifier("batchLookupSearchButton")
                    .disabled(isLookingUp || brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || batchCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let lookupMessage {
                        Text(lookupMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let externalLookup {
                        Button {
                            openURL(externalLookup.url)
                        } label: {
                            Label(
                                AppStrings.text(
                                    "去 \(externalLookup.name) 查询",
                                    "Check on \(externalLookup.name)"
                                ),
                                systemImage: "safari"
                            )
                        }
                        .accessibilityIdentifier("batchLookupExternalLookupButton")

                        Text(externalLookup.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(AppStrings.text("批号查询", "Batch Lookup"))
                } footer: {
                    Text(AppStrings.text("没有可靠品牌规则时，应用会建议外部查询并让你手动记录日期。", "When no reliable brand rule exists, the app suggests an external lookup and lets you record dates manually."))
                }

                Section {
                    Toggle(AppStrings.text("已查到生产日期", "Found manufacture date"), isOn: $hasManufactureDate)
                    if hasManufactureDate {
                        DatePicker(AppStrings.text("生产日期", "Manufacture date"), selection: $manufactureDate, displayedComponents: .date)
                        Stepper(AppStrings.text("未开封 \(shelfLifeMonths) 个月", "Unopened \(shelfLifeMonths) months"), value: $shelfLifeMonths, in: 6...84, step: 6)
                        InfoLine(title: AppStrings.text("估算到期日", "Estimated expiry"), value: estimatedExpiryDate?.shelfFormatted ?? AppStrings.text("待计算", "Pending"))
                    }

                    Stepper(AppStrings.text("开封后 \(openingMonths) 个月", "After opening \(openingMonths) months"), value: $openingMonths, in: 3...48, step: 3)
                } header: {
                    Text(AppStrings.text("估算器", "Estimator"))
                }

                Section {
                    Label(AppStrings.text("护肤和彩妆常见未开封约 24-36 个月", "Skincare and makeup are often about 24-36 months unopened"), systemImage: "calendar")
                    Label(AppStrings.text("PAO 图标如 6M/12M/24M 表示开封后月份", "PAO icons like 6M/12M/24M mean months after opening"), systemImage: "capsule")
                    Label(AppStrings.text("香水通常更看保存环境，避光避热更重要", "Fragrance depends heavily on storage; avoid heat and light"), systemImage: "sparkles")
                } header: {
                    Text(AppStrings.text("常见参考", "Common References"))
                }
            }
            .navigationTitle(AppStrings.text("批号与保质期", "Batch & Shelf Life"))
        }
    }

    @MainActor
    private func lookupBatchCode() async {
        isLookingUp = true
        defer { isLookingUp = false }

        let service = ProductLookupService()
        guard let result = await service.lookupBatchCode(brand: brand, batchCode: batchCode) else {
            externalLookup = nil
            lookupMessage = AppStrings.text(
                "没有找到可靠的批号解析结果，请手动输入生产日期。",
                "No reliable batch-code result found. Enter the manufacture date manually."
            )
            return
        }

        externalLookup = result.suggestedExternalLookup
        lookupMessage = result.message ?? result.sourceDescription

        if let manufactureDate = result.manufactureDate {
            self.manufactureDate = manufactureDate
            hasManufactureDate = true
        }

        if let expiryDate = result.expiryDate {
            let components = Calendar.current.dateComponents(
                [.month],
                from: manufactureDate,
                to: expiryDate
            )
            if let months = components.month, months > 0 {
                shelfLifeMonths = months
            }
        }
    }
}

private struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BatchLookupView()
}
