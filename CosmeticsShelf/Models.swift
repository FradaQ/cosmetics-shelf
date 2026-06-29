import Foundation
import SwiftData
import SwiftUI

enum ProductCategory: String, CaseIterable, Identifiable, Codable {
    case skincare = "护肤"
    case makeup = "彩妆"
    case fragrance = "香水"
    case hairBody = "身体/头发"
    case other = "其他"

    var id: String { rawValue }

    var localizedTitle: String {
        if AppLanguage.isChinese {
            return rawValue
        }

        return switch self {
        case .skincare: "Skincare"
        case .makeup: "Makeup"
        case .fragrance: "Fragrance"
        case .hairBody: "Hair & Body"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .skincare: "drop"
        case .makeup: "paintpalette"
        case .fragrance: "sparkles"
        case .hairBody: "figure.wave"
        case .other: "tray"
        }
    }

    var tint: Color {
        switch self {
        case .skincare: .teal
        case .makeup: .pink
        case .fragrance: .indigo
        case .hairBody: .green
        case .other: .gray
        }
    }
}

enum ExpirySource: String, CaseIterable, Identifiable, Codable {
    case unopened = "按生产日期估算"
    case opened = "按开封后期限"
    case manual = "手动录入"

    var id: String { rawValue }

    var localizedTitle: String {
        if AppLanguage.isChinese {
            return rawValue
        }

        return switch self {
        case .unopened: "Estimated from manufacture date"
        case .opened: "Based on period after opening"
        case .manual: "Entered manually"
        }
    }
}

enum ExpiryStatus: String {
    case expired = "已过期"
    case useSoon = "半年内该用了"
    case good = "状态良好"
    case unknown = "待补全"

    var symbol: String {
        switch self {
        case .expired: "exclamationmark.triangle.fill"
        case .useSoon: "bell.badge.fill"
        case .good: "checkmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var localizedTitle: String {
        if AppLanguage.isChinese {
            return rawValue
        }

        return switch self {
        case .expired: "Expired"
        case .useSoon: "Use soon"
        case .good: "Good"
        case .unknown: "Missing dates"
        }
    }

    var tint: Color {
        switch self {
        case .expired: .red
        case .useSoon: .orange
        case .good: .green
        case .unknown: .secondary
        }
    }
}

@Model
final class ProductItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var localName: String = ""
    var englishName: String = ""
    var brand: String
    var productImageURL: String = ""
    var officialProductURL: String = ""
    var categoryRawValue: String
    var batchCode: String
    var purchaseDate: Date
    var manufactureDate: Date?
    var openedDate: Date?
    var manualExpiryDate: Date?
    var unopenedShelfLifeMonths: Int
    var periodAfterOpeningMonths: Int
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        localName: String = "",
        englishName: String = "",
        brand: String,
        productImageURL: String = "",
        officialProductURL: String = "",
        category: ProductCategory,
        batchCode: String = "",
        purchaseDate: Date = .now,
        manufactureDate: Date? = nil,
        openedDate: Date? = nil,
        manualExpiryDate: Date? = nil,
        unopenedShelfLifeMonths: Int = 36,
        periodAfterOpeningMonths: Int = 12,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.localName = localName
        self.englishName = englishName
        self.brand = brand
        self.productImageURL = productImageURL
        self.officialProductURL = officialProductURL
        self.categoryRawValue = category.rawValue
        self.batchCode = batchCode
        self.purchaseDate = purchaseDate
        self.manufactureDate = manufactureDate
        self.openedDate = openedDate
        self.manualExpiryDate = manualExpiryDate
        self.unopenedShelfLifeMonths = unopenedShelfLifeMonths
        self.periodAfterOpeningMonths = periodAfterOpeningMonths
        self.notes = notes
        self.createdAt = .now
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var displayName: String {
        let preferredName = AppLanguage.isChinese ? localName : englishName
        let fallbackName = AppLanguage.isChinese ? englishName : localName
        return [preferredName, fallbackName, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? name
    }

    var secondaryDisplayName: String? {
        let candidates = AppLanguage.isChinese ? [englishName, name] : [localName, name]
        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != displayName }
    }

    var inventoryIdentifierText: String? {
        let batch = batchCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [
            manufactureDate.map { AppStrings.text("生产 \($0.shelfFormatted)", "Mfg \($0.shelfFormatted)") },
            batch.isEmpty ? nil : AppStrings.text("批号 \(batch)", "Batch \(batch)")
        ].compactMap { $0 }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    var expiryDisplayText: String {
        guard let expiryDate else {
            return AppStrings.text("待补全", "Missing")
        }

        return AppStrings.text("到期 \(expiryDate.shelfFormatted)", "Expires \(expiryDate.shelfFormatted)")
    }

    var productImage: URL? {
        URL(string: productImageURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var officialProduct: URL? {
        URL(string: officialProductURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var expiryDate: Date? {
        expiryCandidates.min { $0.date < $1.date }?.date
    }

    private var expiryCandidates: [(date: Date, source: ExpirySource)] {
        let calendar = Calendar.current
        var candidates: [(date: Date, source: ExpirySource)] = []

        if let manualExpiryDate {
            candidates.append((manualExpiryDate, .manual))
        }

        if let manufactureDate,
           let unopenedDate = calendar.date(byAdding: .month, value: unopenedShelfLifeMonths, to: manufactureDate) {
            candidates.append((unopenedDate, .unopened))
        }

        if let openedDate,
           let openedExpiry = calendar.date(byAdding: .month, value: periodAfterOpeningMonths, to: openedDate) {
            candidates.append((openedExpiry, .opened))
        }

        return candidates
    }

    var remindFromDate: Date? {
        guard let expiryDate else { return nil }
        return Calendar.current.date(byAdding: .month, value: -6, to: expiryDate)
    }

    var status: ExpiryStatus {
        guard let expiryDate else { return .unknown }
        let today = Calendar.current.startOfDay(for: .now)
        let expiryDay = Calendar.current.startOfDay(for: expiryDate)

        if expiryDay < today {
            return .expired
        }

        if let remindFromDate, Calendar.current.startOfDay(for: remindFromDate) <= today {
            return .useSoon
        }

        return .good
    }

    var expiryBasis: ExpirySource {
        expiryCandidates.min { $0.date < $1.date }?.source ?? .unopened
    }
}

extension ProductItem {
    static let samples: [ProductItem] = [
        ProductItem(
            name: "Advanced Night Repair",
            localName: "小棕瓶精华",
            englishName: "Advanced Night Repair",
            brand: "Estée Lauder",
            category: .skincare,
            batchCode: "A83",
            purchaseDate: .now,
            manufactureDate: Calendar.current.date(byAdding: .month, value: -28, to: .now),
            openedDate: Calendar.current.date(byAdding: .month, value: -7, to: .now),
            periodAfterOpeningMonths: 12
        ),
        ProductItem(
            name: "Libre Eau de Parfum",
            localName: "自由之水浓香水",
            englishName: "Libre Eau de Parfum",
            brand: "YSL",
            category: .fragrance,
            batchCode: "38U90D",
            manufactureDate: Calendar.current.date(byAdding: .month, value: -10, to: .now),
            unopenedShelfLifeMonths: 60,
            periodAfterOpeningMonths: 36
        )
    ]
}

enum AppLanguage {
    static var isChinese: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true
    }
}

enum AppStrings {
    static func text(_ chinese: String, _ english: String) -> String {
        AppLanguage.isChinese ? chinese : english
    }
}

extension Date {
    var shelfFormatted: String {
        formatted(.dateTime.year().month(.abbreviated).day())
    }
}
