import SwiftUI

struct BatchLookupView: View {
    @Environment(\.openURL) private var openURL
    @State private var brand = ""
    @State private var batchCode = ""
    @State private var manufactureDate = Date()
    @State private var hasManufactureDate = false
    @State private var shelfLifeMonths = 36
    @State private var openingMonths = 12

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
                        openSearch()
                    } label: {
                        Label(AppStrings.text("搜索批号生产日期", "Search batch manufacture date"), systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("batchLookupSearchButton")
                    .disabled(brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || batchCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text(AppStrings.text("批号查询", "Batch Lookup"))
                } footer: {
                    Text(AppStrings.text("第一版先帮你组织搜索词和记录估算结果。后续可以把你信任的网站或品牌规则接成自动解析。", "This version helps compose the search and record estimates. Trusted sites or brand-specific rules can be automated next."))
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

    private func openSearch() {
        let query = "\(brand) \(batchCode.uppercased()) cosmetic batch code manufacture date"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            openURL(url)
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
