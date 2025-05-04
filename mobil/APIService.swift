import Foundation
import Combine

class APIService {
    static let shared = APIService()
    
    private let coinGeckoURL = "https://api.coingecko.com/api/v3"
    private let binanceURL = "https://api.binance.com/api/v3"
    private let coinCapURL = "https://api.coincap.io/v2"
    private let cryptoPanicURL = "https://cryptopanic.com/api/v1"
    private let newsAPIURL = "https://newsapi.org/v2"
    private let coinStatsAPI = "https://api.coinstats.app/public/v1"
    
    // Add your API keys here
    private let cryptoPanicKey = "ac278e4633ac912593fdf81fae619aa4fe7bd8d1"
    private let newsAPIKey = "d718195189714c7f87c9aa19fabc0169"
    private let coinStatsKey = "nygWaH29Z4o0H6DizGxfm0S2/3MT2Ud46fQojcGGAR8="
    
    private var newsTimer: Timer?
    private var newsUpdateCallback: (([NewsItem]) -> Void)?
    
    private init() {}
    
    // MARK: - Coin Methods
    
    private func getLogoURL(symbol: String) -> String {
        return "https://assets.coingecko.com/coins/images/1/large/\(symbol.lowercased()).png"
    }
    
    func fetchCoins(page: Int, perPage: Int) async throws -> [Coin] {
        print("🔍 Fetching coins page \(page) with \(perPage) per page")
        var allCoins: [Coin] = []
        var errors: [Error] = []
        
        // Try CoinGecko
        do {
            print("🔍 Trying CoinGecko API...")
            allCoins = try await fetchCoinsFromCoinGecko(page: page, perPage: perPage)
            print("✅ CoinGecko success: \(allCoins.count) coins")
            return allCoins
        } catch {
            print("❌ CoinGecko failed: \(error)")
            errors.append(error)
            
            // Try CoinStats
            do {
                print("🔍 Trying CoinStats API...")
                allCoins = try await fetchCoinsFromCoinStats(limit: perPage, skip: (page - 1) * perPage)
                print("✅ CoinStats success: \(allCoins.count) coins")
                return allCoins
            } catch {
                print("❌ CoinStats failed: \(error)")
                errors.append(error)
                
                // Try CoinCap
                do {
                    print("🔍 Trying CoinCap API...")
                    allCoins = try await fetchCoinsFromCoinCap(limit: perPage, offset: (page - 1) * perPage)
                    print("✅ CoinCap success: \(allCoins.count) coins")
                    return allCoins
                } catch {
                    print("❌ CoinCap failed: \(error)")
                    errors.append(error)
                    
                    // If all APIs failed, throw a specific error
                    print("❌❌❌ All API sources failed!")
                    throw APIError.allAPIsFailed
                }
            }
        }
    }
    
    private func fetchCoinsFromCoinGecko(page: Int, perPage: Int) async throws -> [Coin] {
        let urlString = "\(coinGeckoURL)/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=\(perPage)&page=\(page)&sparkline=false&price_change_percentage=24h"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let coins = try decoder.decode([CoinGeckoData].self, from: data)
        
        return coins.map { coinData in
            Coin(
                id: coinData.id,
                name: coinData.name,
                symbol: coinData.symbol.uppercased(),
                price: coinData.currentPrice,
                change24h: coinData.priceChangePercentage24h,
                marketCap: coinData.marketCap,
                image: coinData.image,
                rank: coinData.marketCapRank ?? 0
            )
        }
    }
    
    private func fetchCoinsFromCoinStats(limit: Int, skip: Int = 0) async throws -> [Coin] {
        var request = URLRequest(url: URL(string: "\(coinStatsAPI)/coins?limit=\(limit)&skip=\(skip)")!)
        request.setValue(coinStatsKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let statsResponse = try JSONDecoder().decode(CoinStatsResponse.self, from: data)
        return statsResponse.coins.enumerated().map { index, coin in
            Coin(
                id: coin.id,
                name: coin.name,
                symbol: coin.symbol.uppercased(),
                price: coin.price,
                change24h: coin.priceChange1d,
                marketCap: coin.marketCap,
                image: coin.icon,
                rank: skip + index + 1
            )
        }
    }
    
    private func fetchCoinsFromCoinCap(limit: Int, offset: Int = 0) async throws -> [Coin] {
        let urlString = "\(coinCapURL)/assets?limit=\(limit)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let coinCapResponse = try decoder.decode(CoinCapResponse.self, from: data)
        
        return coinCapResponse.data.enumerated().map { index, coinData in
            Coin(
                id: coinData.id,
                name: coinData.name,
                symbol: coinData.symbol.uppercased(),
                price: Double(coinData.priceUsd) ?? 0,
                change24h: Double(coinData.changePercent24Hr) ?? 0,
                marketCap: Double(coinData.marketCapUsd) ?? 0,
                image: "https://assets.coincap.io/assets/icons/\(coinData.symbol.lowercased())@2x.png",
                rank: Int(coinData.rank) ?? (offset + index + 1)
            )
        }
    }
    
    // MARK: - News Methods
    
    func startNewsUpdates(callback: @escaping ([NewsItem]) -> Void) {
        self.newsUpdateCallback = callback
        
        // Fetch immediately
        Task {
            await fetchAndDeliverNews()
        }
        
        // Setup timer for periodic updates (every 5 minutes)
        newsTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchAndDeliverNews()
            }
        }
    }
    
    func stopNewsUpdates() {
        newsTimer?.invalidate()
        newsTimer = nil
        newsUpdateCallback = nil
    }
    
    private func fetchAndDeliverNews() async {
        do {
            let news = try await fetchNews()
            DispatchQueue.main.async {
                self.newsUpdateCallback?(news)
            }
        } catch {
            print("Failed to fetch news: \(error)")
        }
    }
    
    public func fetchNews() async throws -> [NewsItem] {
        print("📰 Starting to fetch news from all sources...")
        var allNews: [NewsItem] = []
        
        // CryptoPanic
        do {
            print("📰 Fetching from CryptoPanic...")
            let cryptoPanicNews = try await fetchCryptoPanicNews()
            allNews.append(contentsOf: cryptoPanicNews)
            print("✅ CryptoPanic: Got \(cryptoPanicNews.count) news items")
        } catch {
            print("❌ CryptoPanic failed: \(error)")
        }
        
        // NewsAPI
        do {
            print("📰 Fetching from NewsAPI...")
            let newsAPINews = try await fetchNewsAPINews()
            allNews.append(contentsOf: newsAPINews)
            print("✅ NewsAPI: Got \(newsAPINews.count) news items")
        } catch {
            print("❌ NewsAPI failed: \(error)")
        }
        
        // CoinStats
        do {
            print("📰 Fetching from CoinStats...")
            let coinStatsNews = try await fetchCoinStatsNews()
            allNews.append(contentsOf: coinStatsNews)
            print("✅ CoinStats: Got \(coinStatsNews.count) news items")
        } catch {
            print("❌ CoinStats failed: \(error)")
        }
        
        print("📰 Total news items: \(allNews.count)")
        return allNews.sorted(by: >)
    }
    
    private func fetchCryptoPanicNews() async throws -> [NewsItem] {
        let url = URL(string: "\(cryptoPanicURL)/posts/?auth_token=\(cryptoPanicKey)&currencies=BTC,ETH")!
        print("🔗 CryptoPanic URL: \(url)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 CryptoPanic Status Code: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("❌ CryptoPanic Error Response: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.invalidResponse
            }
        }
        
        let panicResponse = try JSONDecoder().decode(CryptoPanicResponse.self, from: data)
        return panicResponse.results.map { result in
            NewsItem(
                id: result.id,
                title: result.title,
                description: result.metadata?.description ?? "",
                url: result.url,
                imageUrl: result.metadata?.image ?? "",
                source: result.source.title,
                publishedAt: result.publishedAt
            )
        }
    }
    
    private func fetchNewsAPINews() async throws -> [NewsItem] {
        let url = URL(string: "\(newsAPIURL)/everything?q=cryptocurrency&apiKey=\(newsAPIKey)&pageSize=50")!
        print("🔗 NewsAPI URL: \(url)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 NewsAPI Status Code: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("❌ NewsAPI Error Response: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.invalidResponse
            }
        }
        
        let newsResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
        return newsResponse.articles.map { article in
            NewsItem(
                id: article.url,
                title: article.title,
                description: article.description ?? "",
                url: article.url,
                imageUrl: article.urlToImage ?? "",
                source: article.source.name,
                publishedAt: article.publishedAt
            )
        }
    }
    
    private func fetchCoinStatsNews() async throws -> [NewsItem] {
        var request = URLRequest(url: URL(string: "\(coinStatsAPI)/news")!)
        request.setValue(coinStatsKey, forHTTPHeaderField: "X-API-KEY")
        print("🔗 CoinStats URL: \(request.url?.absoluteString ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 CoinStats Status Code: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("❌ CoinStats Error Response: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.invalidResponse
            }
        }
        
        let statsResponse = try JSONDecoder().decode(CoinStatsNewsResponse.self, from: data)
        return statsResponse.news.map { news in
            NewsItem(
                id: news.id,
                title: news.title,
                description: news.description,
                url: news.link,
                imageUrl: news.imgURL ?? "",
                source: news.source,
                publishedAt: news.feedDate
            )
        }
    }
}

// MARK: - Models

enum APIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case decodingError
    case allAPIsFailed
}

// Define the operator function to fix the "Referencing operator function '~='" error
func ~= (left: APIError, right: Error) -> Bool {
    guard let right = right as? APIError else { return false }
    return left == right
}

// Coin Models
struct CoinGeckoData: Codable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let marketCap: Double
    let priceChangePercentage24h: Double
    let marketCapRank: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case marketCapRank = "market_cap_rank"
    }
}

struct BinanceData: Codable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
    
    enum CodingKeys: String, CodingKey {
        case symbol
        case lastPrice = "lastPrice"
        case priceChangePercent = "priceChangePercent"
    }
}

struct CoinCapResponse: Codable {
    let data: [CoinCapData]
}

struct CoinCapData: Codable {
    let id: String
    let rank: String
    let symbol: String
    let name: String
    let priceUsd: String
    let changePercent24Hr: String
    let marketCapUsd: String
}

// CryptoPanic Models
struct CryptoPanicResponse: Codable {
    let results: [CryptoPanicResult]
}

struct CryptoPanicResult: Codable {
    let id: String
    let title: String
    let url: String
    let publishedAt: String
    let source: CryptoPanicSource
    let metadata: CryptoPanicMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case publishedAt = "published_at"
        case source
        case metadata
    }
}

struct CryptoPanicSource: Codable {
    let title: String
}

struct CryptoPanicMetadata: Codable {
    let description: String?
    let image: String?
}

// NewsAPI Models
struct NewsAPIResponse: Codable {
    let articles: [NewsAPIArticle]
}

struct NewsAPIArticle: Codable {
    let source: NewsAPISource
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
}

struct NewsAPISource: Codable {
    let name: String
}

// CoinStats Models
struct CoinStatsResponse: Codable {
    let coins: [CoinStatsCoin]
}

struct CoinStatsCoin: Codable {
    let id: String
    let symbol: String
    let name: String
    let icon: String
    let price: Double
    let marketCap: Double
    let priceChange1d: Double
}

// CoinStats News Models
struct CoinStatsNewsResponse: Codable {
    let news: [CoinStatsNews]
}

struct CoinStatsNews: Codable {
    let id: String
    let title: String
    let description: String
    let link: String
    let imgURL: String?
    let source: String
    let feedDate: String
} 