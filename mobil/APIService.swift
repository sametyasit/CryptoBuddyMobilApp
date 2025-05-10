import Foundation
import Combine
import Network
import SwiftUI

// Actor kullanarak thread-safe bir coin ID takip sistemi oluşturalım
actor CoinIDTracker {
    private var loadedCoinIds = Set<String>()
    
    func addCoinIds(_ ids: [String]) {
        loadedCoinIds.formUnion(ids)
    }
    
    func contains(_ id: String) -> Bool {
        return loadedCoinIds.contains(id)
    }
    
    func clear() {
        loadedCoinIds.removeAll()
    }
    
    func filterUniqueCoins(_ coins: [Coin]) -> [Coin] {
        let uniqueCoins = coins.filter { !loadedCoinIds.contains($0.id) }
        
        for coin in uniqueCoins {
            loadedCoinIds.insert(coin.id)
        }
        
        return uniqueCoins
    }
}

class APIService: Equatable {
    static let shared = APIService()
    
    // Actor kullanarak thread-safe yap
    private let coinTracker = CoinIDTracker()
    
    private let coinGeckoURL = "https://api.coingecko.com/api/v3"
    private let coinCapURL = "https://api.coincap.io/v2"
    private let coinMarketCapURL = "https://pro-api.coinmarketcap.com/v1"
    
    // API Anahtarları
    private let coinGeckoKey = "CG-Ld9nYXMFXXHFBGBKASqQj12H"
    private let coinMarketCapKey = "db3b4ffd-e54b-47ab-a1a5-67cefea8582b"
    private let coinAPIKey = "16ebef28-ab58-42bf-a94b-5261121aab9c"
    private let cryptoAPIsKey = "b7995dc6681220bcc35601665acf8166cd72d06d"
    
    // Environment Object
    private var networkMonitor: NetworkMonitorViewModel?
    
    private init() {}
    
    // Environment Object'i ayarlamak için metod
    func configure(with networkMonitor: NetworkMonitorViewModel) {
        self.networkMonitor = networkMonitor
    }
    
    // Ağ bağlantısını kontrol et
    private var isConnectedToNetwork: Bool {
        return networkMonitor?.isConnected ?? true
    }
    
    // Önbellek için yapı
    private var coinCache: [String: (timestamp: Date, response: APIResponse)] = [:]
    private let cacheValidDuration: TimeInterval = 60
    
    // Önbellek temizleme metodu
    func clearCoinsCache() {
        print("🧹 Coin önbelleği temizleniyor...")
        coinCache.removeAll()
        
        // ID'leri temizle
        Task {
            await coinTracker.clear()
        }
        
        print("✅ Önbellek temizlendi")
    }
    
    // Yüklenen coin ID'lerini temizlemek için metod
    func clearLoadedCoinIds() {
        print("🧹 Yüklenen coin ID'leri temizleniyor...")
        Task {
            await coinTracker.clear()
        }
        print("✅ Yüklenen coin ID'leri temizlendi")
    }
    
    // API yanıt tipi için struct
    struct APIResponse {
        let coins: [Coin]
        let source: String
        
        // 'first' metodu ekliyoruz
        var first: Coin? {
            return coins.first
        }
        
        // İndex ile erişim
        subscript(index: Int) -> Coin {
            return coins[index]
        }
        
        // Özel filtreleme için
        func first(where predicate: (Coin) -> Bool) -> Coin? {
            return coins.first(where: predicate)
        }
    }
    
    // MARK: - Main API Methods
    
    @Sendable
    func fetchCoins(page: Int, perPage: Int) async throws -> APIResponse {
        print("🔍 Coinler alınıyor: Sayfa \(page), sayfa başına \(perPage) coin")
        
        // İlk sayfa için ID'leri temizle
        if page == 1 {
            await coinTracker.clear()
        }
        
        // Önbellekten kontrol et
        let cacheKey: String = "coins_\(page)_\(perPage)"
        if let cached = coinCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidDuration {
            print("✅ Önbellekten veri kullanılıyor (sayfa \(page)) - \(cached.response.coins.count) coin")
            await coinTracker.addCoinIds(cached.response.coins.map { $0.id })
            return cached.response
        }
        
        // Tüm API'leri dene, herhangi biri başarılı olursa onu kullan
        do {
            // 1. CoinGecko
            return try await fetchFromCoinGecko(page: page, perPage: perPage, cacheKey: cacheKey)
        } catch {
            print("⚠️ CoinGecko API hatası: \(error.localizedDescription)")
            do {
                // 2. CoinCap
                return try await fetchFromCoinCap(page: page, perPage: perPage, cacheKey: cacheKey)
            } catch {
                print("⚠️ CoinCap API hatası: \(error.localizedDescription)")
                do {
                    // 3. CoinMarketCap
                    return try await fetchFromCoinMarketCap(page: page, perPage: perPage, cacheKey: cacheKey)
                } catch {
                    print("⚠️ CoinMarketCap API hatası: \(error.localizedDescription)")
                    do {
                        // 4. CoinAPI
                        return try await fetchFromCoinAPI(page: page, perPage: perPage, cacheKey: cacheKey)
                    } catch {
                        print("⚠️ CoinAPI hatası: \(error.localizedDescription)")
                        do {
                            // 5. CryptoAPIs
                            return try await fetchFromCryptoAPIs(page: page, perPage: perPage, cacheKey: cacheKey)
                        } catch {
                            print("⚠️ CryptoAPIs API hatası: \(error.localizedDescription)")
                            throw APIError.allAPIsFailed
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Individual API Fetchers
    
    private func fetchFromCoinGecko(page: Int, perPage: Int, cacheKey: String) async throws -> APIResponse {
        print("🔍 CoinGecko API kullanılıyor...")
        
        let urlString = "\(coinGeckoURL)/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=\(perPage)&page=\(page)&sparkline=false&price_change_percentage=24h"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if !coinGeckoKey.isEmpty {
            request.addValue(coinGeckoKey, forHTTPHeaderField: "x-cg-pro-api-key")
        }
        
        // User-Agent ekle
        request.addValue("CryptoBuddy/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let geckoCoins = try decoder.decode([CoinGeckoData].self, from: data)
        
        let mappedCoins = geckoCoins.map { coinData in
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
        
        // Benzersiz coinleri filtrele
        let uniqueCoins = await coinTracker.filterUniqueCoins(mappedCoins)
        
        print("✅ CoinGecko başarılı: \(mappedCoins.count) coin bulundu, \(uniqueCoins.count) benzersiz")
        
        let geckoResponse: APIResponse = APIResponse(coins: uniqueCoins, source: "CoinGecko")
        coinCache[cacheKey] = (Date(), geckoResponse)
        
        return geckoResponse
    }
    
    private func fetchFromCoinCap(page: Int, perPage: Int, cacheKey: String) async throws -> APIResponse {
        print("🔍 CoinCap API kullanılıyor...")
        
        let offset = (page - 1) * perPage
        let urlString = "\(coinCapURL)/assets?limit=\(perPage)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        // CoinCap API key eklenmedi, genellikle anahtarsız da çalışır
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let coinCapResponse = try decoder.decode(CoinCapResponse.self, from: data)
        
        let mappedCoins = coinCapResponse.data.enumerated().map { index, coinData in
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
        
        // Benzersiz coinleri filtrele
        let uniqueCoins = await coinTracker.filterUniqueCoins(mappedCoins)
        
        print("✅ CoinCap başarılı: \(mappedCoins.count) coin bulundu, \(uniqueCoins.count) benzersiz")
        
        let capResponse: APIResponse = APIResponse(coins: uniqueCoins, source: "CoinCap")
        coinCache[cacheKey] = (Date(), capResponse)
        
        return capResponse
    }
    
    private func fetchFromCoinMarketCap(page: Int, perPage: Int, cacheKey: String) async throws -> APIResponse {
        print("🔍 CoinMarketCap API kullanılıyor...")
        
        let start = (page - 1) * perPage + 1
        let urlString = "\(coinMarketCapURL)/cryptocurrency/listings/latest"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        // API anahtarını ekle (CoinMarketCap için gerekli)
        request.addValue(coinMarketCapKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Parametreleri ekle
        let parameters = [
            "start": "\(start)",
            "limit": "\(perPage)",
            "convert": "USD"
        ]
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        if let paramURL = components.url {
            request.url = paramURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let cmcResponse = try decoder.decode(CoinMarketCapResponse.self, from: data)
        
        let mappedCoins = cmcResponse.data.map { coinData in
            let usdQuote = coinData.quote["USD"] ?? CoinMarketCapQuote(price: 0, volume24h: 0, percentChange24h: 0, marketCap: 0)
            
            return Coin(
                id: "\(coinData.id)".lowercased(),
                name: coinData.name,
                symbol: coinData.symbol,
                price: usdQuote.price,
                change24h: usdQuote.percentChange24h,
                marketCap: usdQuote.marketCap,
                image: "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coinData.id).png",
                rank: coinData.cmcRank
            )
        }
        
        // Benzersiz coinleri filtrele
        let uniqueCoins = await coinTracker.filterUniqueCoins(mappedCoins)
        
        print("✅ CoinMarketCap başarılı: \(mappedCoins.count) coin bulundu, \(uniqueCoins.count) benzersiz")
        
        let cmcApiResponse: APIResponse = APIResponse(coins: uniqueCoins, source: "CoinMarketCap")
        coinCache[cacheKey] = (Date(), cmcApiResponse)
        
        return cmcApiResponse
    }
    
    // CoinAPI'den veri çekme fonksiyonu
    private func fetchFromCoinAPI(page: Int, perPage: Int, cacheKey: String) async throws -> APIResponse {
        print("🔍 CoinAPI kullanılıyor...")
        let urlString = "https://rest.coinapi.io/v1/assets?limit=\(perPage)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.addValue(coinAPIKey, forHTTPHeaderField: "X-CoinAPI-Key")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        struct CoinAPIAsset: Codable {
            let asset_id: String
            let name: String?
            let price_usd: Double?
        }
        let decoder = JSONDecoder()
        let coinAPIAssets = try decoder.decode([CoinAPIAsset].self, from: data)
        let mappedCoins = coinAPIAssets.prefix(perPage).enumerated().map { (index, asset) in
            Coin(
                id: asset.asset_id.lowercased(),
                name: asset.name ?? asset.asset_id,
                symbol: asset.asset_id,
                price: asset.price_usd ?? 0,
                change24h: 0, // CoinAPI'de yok
                marketCap: 0, // CoinAPI'de yok
                image: "",
                rank: index + 1
            )
        }
        let uniqueCoins = await coinTracker.filterUniqueCoins(mappedCoins)
        let apiResponse = APIResponse(coins: uniqueCoins, source: "CoinAPI")
        coinCache[cacheKey] = (Date(), apiResponse)
        return apiResponse
    }
    
    // CryptoAPIs'den veri çekme fonksiyonu
    private func fetchFromCryptoAPIs(page: Int, perPage: Int, cacheKey: String) async throws -> APIResponse {
        print("🔍 CryptoAPIs kullanılıyor...")
        let urlString = "https://rest.cryptoapis.io/v2/market-data/assets?limit=\(perPage)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.addValue(cryptoAPIsKey, forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        struct CryptoAPIsAsset: Codable {
            let assetId: String
            let name: String
            let symbol: String
            let currentPrice: Double?
        }
        struct CryptoAPIsResponse: Codable {
            let data: [CryptoAPIsAsset]
        }
        let decoder = JSONDecoder()
        let decodedResponse = try decoder.decode(CryptoAPIsResponse.self, from: data)
        let mappedCoins = decodedResponse.data.prefix(perPage).enumerated().map { (index, asset) in
            Coin(
                id: asset.assetId.lowercased(),
                name: asset.name,
                symbol: asset.symbol,
                price: asset.currentPrice ?? 0,
                change24h: 0,
                marketCap: 0,
                image: "",
                rank: index + 1
            )
        }
        let uniqueCoins = await coinTracker.filterUniqueCoins(mappedCoins)
        let apiResponse = APIResponse(coins: uniqueCoins, source: "CryptoAPIs")
        coinCache[cacheKey] = (Date(), apiResponse)
        return apiResponse
    }
    
    // MARK: - News Methods
    
    @Sendable
    func fetchNews() async throws -> [APINewsItem] {
        print("📰 Haberler getiriliyor...")
        
        // Haber API'lerini burada ekleyebilirsiniz
        // Şimdilik boş bir liste döndürelim
        return []
    }
    
    // MARK: - Coin Detail Methods
    
    @Sendable
    func fetchCoinDetails(coinId: String) async throws -> Coin {
        print("🔍 Coin detayları alınıyor: \(coinId)")
        
        // Önce mevcut coinler içinde ara
        let allCoins = try await fetchCoins(page: 1, perPage: 100)
        
        if let coin = allCoins.coins.first(where: { $0.id == coinId }) {
            return coin
        }
        
        // Bulunamadıysa hata fırlat
        throw APIError.coinNotFound
    }
    
    @Sendable
    func fetchCoinPriceHistory(coinId: String, days: Int = 7) async throws -> [APIGraphPoint] {
        print("📈 Coin fiyat geçmişi alınıyor: \(coinId)")
        
        // Şimdilik örnek veri oluşturalım
        let now = Date()
        var historyPoints: [APIGraphPoint] = []
        
        for day in 0..<days {
            let timestamp = now.addingTimeInterval(-Double(day * 86400)) // 1 gün = 86400 saniye
            let point = APIGraphPoint(
                timestamp: timestamp.timeIntervalSince1970,
                price: Double.random(in: 100...50000)
            )
            historyPoints.append(point)
        }
        
        return historyPoints.reversed()
    }
    
    // MARK: - Error Enums
    
    enum APIError: Error, Equatable {
        case invalidURL
        case invalidResponse
        case decodingError
        case allAPIsFailed
        case coinNotFound
        case rateLimitExceeded
    }
    
    // MARK: - Models
    
    // GraphPoint modeli
    struct APIGraphPoint: Identifiable {
        let id = UUID()
        let timestamp: TimeInterval
        let price: Double
        
        var date: Date {
            return Date(timeIntervalSince1970: timestamp)
        }
    }
    
    // NewsItem modeli
    struct APINewsItem: Identifiable, Comparable {
        let id: String
        let title: String
        let description: String
        let url: String
        let imageUrl: String
        let source: String
        let publishedAt: String
        
        static func < (lhs: APINewsItem, rhs: APINewsItem) -> Bool {
            return lhs.publishedAt > rhs.publishedAt // Daha yeni olanlar önce
        }
        
        static func > (lhs: APINewsItem, rhs: APINewsItem) -> Bool {
            return lhs.publishedAt < rhs.publishedAt
        }
    }
    
    // Equatable protokolü için gerekli uygulama
    static func == (lhs: APIService, rhs: APIService) -> Bool {
        return lhs === rhs // Referans eşitliği - bu bir singleton olduğundan her zaman eşit olacak
    }
}

// MARK: - Models

// CoinGecko Modelleri
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

// CoinCap Modelleri
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

struct CoinStatisticsResult: Codable {
    let type: Int
}

// CoinMarketCap için model sınıfları
struct CoinMarketCapResponse: Codable {
    let status: CoinMarketCapStatus
    let data: [CoinMarketCapData]
}

struct CoinMarketCapStatus: Codable {
    let timestamp: String
    let errorCode: Int
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }
}

struct CoinMarketCapData: Codable {
    let id: Int
    let name: String
    let symbol: String
    let cmcRank: Int
    let quote: [String: CoinMarketCapQuote]
    
    enum CodingKeys: String, CodingKey {
        case id, name, symbol
        case cmcRank = "cmc_rank"
        case quote
    }
}

struct CoinMarketCapQuote: Codable {
    let price: Double
    let volume24h: Double
    let percentChange24h: Double
    let marketCap: Double
    
    enum CodingKeys: String, CodingKey {
        case price
        case volume24h = "volume_24h"
        case percentChange24h = "percent_change_24h"
        case marketCap = "market_cap"
    }
} 
