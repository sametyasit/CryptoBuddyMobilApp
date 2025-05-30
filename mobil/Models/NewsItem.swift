import Foundation

struct NewsItem: Identifiable, Comparable, Codable {
    let id: String
    let title: String
    let description: String
    let url: String
    let imageUrl: String
    let source: String
    let publishedAt: String
    
    // Implement Comparable for sorting
    static func < (lhs: NewsItem, rhs: NewsItem) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let lhsDate = formatter.date(from: lhs.publishedAt),
              let rhsDate = formatter.date(from: rhs.publishedAt) else {
            return false
        }
        
        return lhsDate < rhsDate
    }
    
    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// API model dönüştürme uzantısı
extension NewsItem {
    // API modelinden dönüştürme - Farklı isim verdik
    static func convertFromAPIModel(_ apiModel: APIService.APINewsItem) -> NewsItem {
        return NewsItem(
            id: apiModel.id,
            title: apiModel.title,
            description: apiModel.description,
            url: apiModel.url,
            imageUrl: apiModel.imageUrl,
            source: apiModel.source,
            publishedAt: apiModel.publishedAt
        )
    }
} 