import Foundation

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

// MARK: - Unified News Item Model
struct NewsItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
    let imageUrl: String
    let publishedAt: Date
    let source: String
    let category: NewsCategory
    
    init(from cryptoCompare: CryptoCompareNewsItem) {
        self.title = cryptoCompare.title
        self.description = cryptoCompare.body
        self.url = cryptoCompare.url
        self.imageUrl = cryptoCompare.imageurl
        self.publishedAt = Date(timeIntervalSince1970: cryptoCompare.published_on)
        self.source = "CryptoCompare: \(cryptoCompare.source)"
        self.category = .all
    }
    
    init(from cryptoNews: CryptoNewsItem) {
        self.title = cryptoNews.title
        self.description = cryptoNews.description
        self.url = cryptoNews.url
        self.imageUrl = cryptoNews.image
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.publishedAt = formatter.date(from: cryptoNews.publishedAt) ?? Date()
        self.source = "CryptoNews: \(cryptoNews.source)"
        self.category = .all
    }
    
    init(from coinGecko: CoinGeckoNewsItem) {
        self.title = coinGecko.title
        self.description = coinGecko.description
        self.url = coinGecko.url
        self.imageUrl = coinGecko.thumb_2x
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.publishedAt = formatter.date(from: coinGecko.created_at) ?? Date()
        self.source = "CoinGecko: \(coinGecko.author)"
        self.category = .all
    }
}

// MARK: - News Category
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

// MARK: - Error Types
enum NewsError: Error {
    case invalidResponse
    case allAPIsFailed
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .allAPIsFailed:
            return "Unable to fetch news from any source"
        case .invalidData:
            return "Invalid data received from server"
        }
    }
} 