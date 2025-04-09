import Foundation
import SwiftUI

// MARK: - Error Types
enum NewsError: Error {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case allAPIsFailed
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Error parsing data"
        case .allAPIsFailed:
            return "Unable to fetch news from any source"
        case .invalidData:
            return "Invalid data received from server"
        }
    }
}

// MARK: - Response Models
struct CryptoCompareNewsResponse: Codable {
    let Data: [CryptoCompareNewsItem]
}

struct CryptoCompareNewsItem: Codable {
    let id: String
    let title: String
    let body: String
    let categories: String
    let url: String
    let imageurl: String
    let published_on: TimeInterval
    let source: String
}

struct CryptoNewsResponse: Codable {
    let data: [CryptoNewsItem]
}

struct CryptoNewsItem: Codable {
    let title: String
    let description: String
    let url: String
    let image: String
    let publishedAt: String
    let source: String
}

struct CoinGeckoNewsItem: Codable {
    let title: String
    let description: String
    let url: String
    let thumb_2x: String
    let created_at: String
    let author: String
}

class NewsService {
    static let shared = NewsService()
    
    enum NewsCategory: String, CaseIterable {
        case all = "All"
        case trading = "Trading"
        case technology = "Technology"
        case regulation = "Regulation"
        case mining = "Mining"
        case defi = "DeFi"
        case nft = "NFT"
        case metaverse = "Metaverse"
    }
    
    // MARK: - Unified News Item Model
    struct NewsItem: Identifiable, Hashable {
        let id: String
        let title: String
        let description: String
        let url: String
        let imageUrl: String
        let publishedAt: Date
        let source: String
        let category: NewsCategory
        
        static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        init(from cryptoCompare: CryptoCompareNewsItem) {
            self.id = cryptoCompare.id
            self.title = cryptoCompare.title
            self.description = cryptoCompare.body
            self.url = cryptoCompare.url
            self.imageUrl = cryptoCompare.imageurl
            self.publishedAt = Date(timeIntervalSince1970: cryptoCompare.published_on)
            self.source = "CryptoCompare: \(cryptoCompare.source)"
            self.category = .all
        }
        
        init(from cryptoNews: CryptoNewsItem) {
            self.id = UUID().uuidString
            self.title = cryptoNews.title
            self.description = cryptoNews.description
            self.url = cryptoNews.url
            self.imageUrl = cryptoNews.image
            self.publishedAt = ISO8601DateFormatter().date(from: cryptoNews.publishedAt) ?? Date()
            self.source = "CryptoNews: \(cryptoNews.source)"
            self.category = .all
        }
        
        init(from coinGecko: CoinGeckoNewsItem) {
            self.id = UUID().uuidString
            self.title = coinGecko.title
            self.description = coinGecko.description
            self.url = coinGecko.url
            self.imageUrl = coinGecko.thumb_2x
            self.publishedAt = ISO8601DateFormatter().date(from: coinGecko.created_at) ?? Date()
            self.source = "CoinGecko: \(coinGecko.author)"
            self.category = .all
        }
    }
    
    private init() {}
    
    func fetchNews(category: NewsCategory = .all, page: Int = 1) async throws -> [NewsItem] {
        // Simüle edilmiş veri
        return [
            NewsItem(
                from: CryptoCompareNewsItem(
                    id: UUID().uuidString,
                    title: "Sample News Title",
                    body: "This is a sample news description",
                    categories: category.rawValue,
                    url: "https://example.com",
                    imageurl: "https://example.com/image.jpg",
                    published_on: Date().timeIntervalSince1970,
                    source: "Sample Source"
                )
            )
        ]
    }
} 