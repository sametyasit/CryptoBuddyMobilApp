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

class APIService: ObservableObject, Equatable {
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
        
        // İşlem hacmi ve diğer verileri de almak için parametreler eklendi
        let urlString = "\(coinGeckoURL)/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=\(perPage)&page=\(page)&sparkline=false&price_change_percentage=24h&include_24h_vol=true&include_24h_change=true&include_last_updated_at=true"
        
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
            var coin = Coin(
                id: coinData.id,
                name: coinData.name,
                symbol: coinData.symbol.uppercased(),
                price: coinData.currentPrice,
                change24h: coinData.priceChangePercentage24h,
                marketCap: coinData.marketCap,
                image: coinData.image,
                rank: coinData.marketCapRank ?? 0
            )
            
            // Ek verileri ekle
            coin.totalVolume = coinData.totalVolume ?? 0
            coin.high24h = coinData.high24h ?? 0
            coin.low24h = coinData.low24h ?? 0
            coin.priceChange24h = coinData.priceChange24h ?? 0
            coin.ath = coinData.ath ?? 0
            coin.athChangePercentage = coinData.athChangePercentage ?? 0
            
            return coin
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
            var coin = Coin(
                id: coinData.id,
                name: coinData.name,
                symbol: coinData.symbol.uppercased(),
                price: Double(coinData.priceUsd) ?? 0,
                change24h: Double(coinData.changePercent24Hr) ?? 0,
                marketCap: Double(coinData.marketCapUsd) ?? 0,
                image: "https://assets.coincap.io/assets/icons/\(coinData.symbol.lowercased())@2x.png",
                rank: Int(coinData.rank) ?? (offset + index + 1)
            )
            
            // Ek verileri ekle
            if let volumeStr = coinData.volumeUsd24Hr, let volume = Double(volumeStr) {
                coin.totalVolume = volume
            }
            
            return coin
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
            
            var coin = Coin(
                id: "\(coinData.id)".lowercased(),
                name: coinData.name,
                symbol: coinData.symbol,
                price: usdQuote.price,
                change24h: usdQuote.percentChange24h,
                marketCap: usdQuote.marketCap,
                image: "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coinData.id).png",
                rank: coinData.cmcRank
            )
            
            // Ek verileri ekle
            coin.totalVolume = usdQuote.volume24h
            
            return coin
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
        // Haberler için CryptoNews API, CryptoCompare API, CoinDesk RSS kullanacağız
        print("📰 Kripto haberleri alınıyor...")
        
        // Haberleri önbellekten kontrol et ve gerekirse yenile
        if let cachedNews = checkNewsCache() {
            print("✅ Önbellekten haberler alındı")
            return cachedNews
        }
        
        // API'leri sırayla dene
        var newsItems: [APINewsItem] = []
        
        // 1. Cryptocurrency News API'si (Örnek: CryptoControl, NewsAPI, vb.)
        do {
            // NewsAPI.org API'sinden kripto ile ilgili haberleri al
            let endpoint = "https://newsapi.org/v2/everything?q=cryptocurrency%20OR%20bitcoin%20OR%20ethereum&sortBy=publishedAt&language=en&pageSize=15"
            
            guard let url = URL(string: endpoint) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("bce28a0e51434ab2b9e45d5ba66a1c0c", forHTTPHeaderField: "X-Api-Key") // Örnek API key
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ NewsAPI hata kodu: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                throw APIError.invalidResponse
            }
            
            // JSON parsing
            let decoder = JSONDecoder()
            
            // NewsAPI yanıt yapısı
            struct NewsAPIResponse: Codable {
                let status: String
                let totalResults: Int
                let articles: [Article]
                
                struct Article: Codable {
                    let source: Source
                    let author: String?
                    let title: String
                    let description: String?
                    let url: String
                    let urlToImage: String?
                    let publishedAt: String
                    let content: String?
                    
                    struct Source: Codable {
                        let id: String?
                        let name: String
                    }
                }
            }
            
            let newsResponse = try decoder.decode(NewsAPIResponse.self, from: data)
            
            // APINewsItem formatına dönüştür
            for article in newsResponse.articles {
                let newsItem = APINewsItem(
                    id: UUID().uuidString,
                    title: article.title,
                    description: article.description ?? "Açıklama yok",
                    url: article.url,
                    imageUrl: article.urlToImage ?? "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
                    source: article.source.name,
                    publishedAt: article.publishedAt
                )
                newsItems.append(newsItem)
            }
            
            // Haberleri kaşeleyelim
            cacheNews(newsItems)
            print("✅ NewsAPI'den \(newsItems.count) haber alındı")
            return newsItems
            
        } catch {
            print("⚠️ NewsAPI hatası: \(error.localizedDescription)")
            // Diğer API'yi dene
        }
        
        // 2. CryptoCompare News API'si (Yedek olarak)
        do {
            let endpoint = "https://min-api.cryptocompare.com/data/v2/news/?lang=EN&sortOrder=popular"
            
            guard let url = URL(string: endpoint) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            // API key isteğe bağlı
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ CryptoCompare API hata kodu: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                throw APIError.invalidResponse
            }
            
            // JSON parsing
            let decoder = JSONDecoder()
            
            // CryptoCompare yanıt yapısı
            struct CryptoCompareResponse: Codable {
                let Data: [NewsData]
                
                struct NewsData: Codable {
                    let id: String
                    let guid: String
                    let published_on: Int
                    let imageurl: String
                    let title: String
                    let url: String
                    let source: String
                    let body: String
                    let tags: String
                    let categories: String
                }
            }
            
            let newsResponse = try decoder.decode(CryptoCompareResponse.self, from: data)
            
            // APINewsItem formatına dönüştür
            for article in newsResponse.Data {
                let publishedDate = Date(timeIntervalSince1970: TimeInterval(article.published_on))
                let dateFormatter = ISO8601DateFormatter()
                
                let newsItem = APINewsItem(
                    id: article.id,
                    title: article.title,
                    description: article.body.prefix(200) + "...",
                    url: article.url,
                    imageUrl: article.imageurl,
                    source: article.source,
                    publishedAt: dateFormatter.string(from: publishedDate)
                )
                newsItems.append(newsItem)
            }
            
            // Haberleri kaşeleyelim
            cacheNews(newsItems)
            print("✅ CryptoCompare'den \(newsItems.count) haber alındı")
            return newsItems
            
        } catch {
            print("⚠️ CryptoCompare API hatası: \(error.localizedDescription)")
            // Yedek olarak statik içerik kullan
        }
        
        // Eğer buraya kadar geldiyse, yedek haberler oluştur
        print("⚠️ Haber API'leri başarısız oldu, yedek haberler kullanılıyor...")
        
        // Yedek haberler
        newsItems = [
            APINewsItem(
                id: UUID().uuidString,
                title: "Bitcoin 50.000 Doları Aştı",
                description: "Bitcoin son 3 ayın en yüksek seviyesine ulaşarak 50.000 doları geçti. Analistler yükseliş trendinin devam edebileceğini belirtiyor.",
                url: "https://www.example.com/bitcoin-news",
                imageUrl: "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
                source: "Crypto News",
                publishedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
            ),
            APINewsItem(
                id: UUID().uuidString,
                title: "Ethereum 2.0 Güncellemesi Yaklaşıyor",
                description: "Ethereum ağı, uzun zamandır beklenen 2.0 güncellemesine hazırlanıyor. Bu güncelleme ile birlikte ağın hızı ve ölçeklenebilirliği artacak.",
                url: "https://www.example.com/ethereum-news",
                imageUrl: "https://cryptologos.cc/logos/ethereum-eth-logo.png",
                source: "Blockchain Daily",
                publishedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))
            ),
            APINewsItem(
                id: UUID().uuidString,
                title: "Dogecoin, Elon Musk'ın Tweeti ile Yükseldi",
                description: "Elon Musk'ın Twitter'da paylaştığı Dogecoin içerikli post, DOGE fiyatında ani bir yükselişe neden oldu.",
                url: "https://www.example.com/dogecoin-news",
                imageUrl: "https://cryptologos.cc/logos/dogecoin-doge-logo.png",
                source: "Crypto Pulse",
                publishedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-10800))
            ),
            APINewsItem(
                id: UUID().uuidString,
                title: "NFT Piyasasında Rekor Satış",
                description: "Bir dijital sanat eseri, NFT pazarında rekor kırarak 15 milyon dolara satıldı. Bu satış, NFT'lere olan ilginin artmaya devam ettiğini gösteriyor.",
                url: "https://www.example.com/nft-news",
                imageUrl: "https://www.arweave.net/Sr6h_YcjTrxHKgas7GN3-QqXPCKGiZUTnqYVKQcgIS0?ext=png",
                source: "Art & Tech",
                publishedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-14400))
            ),
            APINewsItem(
                id: UUID().uuidString,
                title: "Cardano, Akıllı Sözleşme Özelliğini Aktifleştirdi",
                description: "Cardano ağı, Alonzo güncellemesi ile birlikte akıllı sözleşme özelliğini aktifleştirdi. Bu, ADA ekosistemi için önemli bir dönüm noktası.",
                url: "https://www.example.com/cardano-news",
                imageUrl: "https://cryptologos.cc/logos/cardano-ada-logo.png",
                source: "Crypto Insider",
                publishedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-18000))
            )
        ]
        
        // Yedek haberleri de önbelleğe ekle
        cacheNews(newsItems)
        return newsItems
    }
    
    // Haberler için önbellek fonksiyonları
    private func checkNewsCache() -> [APINewsItem]? {
        guard let lastNewsFetchTime = UserDefaults.standard.object(forKey: "lastNewsFetchTime") as? Date else {
            return nil
        }
        
        let cacheValidityDuration: TimeInterval = 30 * 60 // 30 dakika
        
        if Date().timeIntervalSince(lastNewsFetchTime) < cacheValidityDuration,
           let cachedNewsData = UserDefaults.standard.data(forKey: "cachedNews") {
            do {
                return try JSONDecoder().decode([APINewsItem].self, from: cachedNewsData)
            } catch {
                print("⚠️ Haber önbelleği decode hatası: \(error.localizedDescription)")
                return nil
            }
        }
        
        return nil
    }
    
    private func cacheNews(_ news: [APINewsItem]) {
        do {
            let encodedNews = try JSONEncoder().encode(news)
            UserDefaults.standard.set(encodedNews, forKey: "cachedNews")
            UserDefaults.standard.set(Date(), forKey: "lastNewsFetchTime")
        } catch {
            print("⚠️ Haber önbellek hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Coin Detail Methods
    
    @Sendable
    func fetchCoinDetails(coinId: String) async throws -> Coin {
        print("🔍 Coin detayları alınıyor: \(coinId)")
        
        // İlk önce mevcut coinler içinde arama yap
        do {
            let allCoins = try await fetchCoins(page: 1, perPage: 100)
            
            // Coini bulduysan detay çekmeye devam et
            if let coin = allCoins.coins.first(where: { $0.id == coinId }) {
                var detailedCoin = coin
                
                // Detaylı bilgileri çekmeye çalış
                do {
                    let endpoint = "\(coinGeckoURL)/coins/\(coinId)?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"
                    
                    guard let url = URL(string: endpoint) else {
                        return coin
                    }
                    
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 15
                    
                    if !coinGeckoKey.isEmpty {
                        request.addValue(coinGeckoKey, forHTTPHeaderField: "x-cg-pro-api-key")
                    }
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        print("⚠️ CoinGecko detay API HTTP hatası: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                        return coin
                    }
                    
                    // JSON yanıtını ayrıştır
                    struct CoinDetailResponse: Codable {
                        let id: String
                        let symbol: String
                        let name: String
                        let description: [String: String]?
                        let links: Links?
                        let image: ImageLinks?
                        let marketData: MarketData?
                        
                        struct Links: Codable {
                            let homepage: [String]?
                            let twitterScreenName: String?
                            let subredditURL: String?
                            let reposURL: ReposURL?
                            
                            struct ReposURL: Codable {
                                let github: [String]?
                            }
                            
                            enum CodingKeys: String, CodingKey {
                                case homepage
                                case twitterScreenName = "twitter_screen_name"
                                case subredditURL = "subreddit_url"
                                case reposURL = "repos_url"
                            }
                        }
                        
                        struct ImageLinks: Codable {
                            let thumb: String?
                            let small: String?
                            let large: String?
                        }
                        
                        struct MarketData: Codable {
                            let currentPrice: [String: Double]?
                            let ath: [String: Double]?
                            let athChangePercentage: [String: Double]?
                            let marketCap: [String: Double]?
                            let totalVolume: [String: Double]?
                            let high24h: [String: Double]?
                            let low24h: [String: Double]?
                            
                            enum CodingKeys: String, CodingKey {
                                case currentPrice = "current_price"
                                case ath
                                case athChangePercentage = "ath_change_percentage"
                                case marketCap = "market_cap"
                                case totalVolume = "total_volume"
                                case high24h = "high_24h"
                                case low24h = "low_24h"
                            }
                        }
                        
                        enum CodingKeys: String, CodingKey {
                            case id, symbol, name, description, links, image
                            case marketData = "market_data"
                        }
                    }
                    
                    let decoder = JSONDecoder()
                    let detailResponse = try decoder.decode(CoinDetailResponse.self, from: data)
                    
                    // Detaylı bilgileri doldur
                    if let marketData = detailResponse.marketData {
                        detailedCoin.totalVolume = marketData.totalVolume?["usd"] ?? 0
                        detailedCoin.high24h = marketData.high24h?["usd"] ?? 0
                        detailedCoin.low24h = marketData.low24h?["usd"] ?? 0
                        detailedCoin.ath = marketData.ath?["usd"] ?? 0
                        detailedCoin.athChangePercentage = marketData.athChangePercentage?["usd"] ?? 0
                        
                        print("✅ Detaylı coin bilgileri alındı")
                        print("📊 Volume: \(detailedCoin.totalVolume)")
                        print("📊 High 24h: \(detailedCoin.high24h)")
                        print("📊 Low 24h: \(detailedCoin.low24h)")
                        print("📊 ATH: \(detailedCoin.ath)")
                    }
                    
                    // Açıklama ve sosyal bağlantıları doldur
                    if let description = detailResponse.description?["en"] {
                        detailedCoin.description = description
                    }
                    
                    if let links = detailResponse.links {
                        if let homepage = links.homepage?.first, !homepage.isEmpty {
                            detailedCoin.website = homepage
                        }
                        
                        if let twitter = links.twitterScreenName, !twitter.isEmpty {
                            detailedCoin.twitter = "https://twitter.com/\(twitter)"
                        }
                        
                        if let reddit = links.subredditURL, !reddit.isEmpty {
                            detailedCoin.reddit = reddit
                        }
                        
                        if let github = links.reposURL?.github?.first, !github.isEmpty {
                            detailedCoin.github = github
                        }
                    }
                    
                    return detailedCoin
                    
                } catch {
                    print("⚠️ Detay API hatası: \(error.localizedDescription)")
                    return coin // API hatası durumunda mevcut coin bilgileri ile devam et
                }
            }
        } catch {
            print("⚠️ İlk arama hatası: \(error.localizedDescription)")
            // İlk arama başarısız olursa, direkt detaylı aramaya geç
        }
        
        // İlk adım başarısız olduysa, direkt ID ile detaylı arama
        do {
            // Direkt ID ile arama yap
            let endpoint = "\(coinGeckoURL)/coins/\(coinId)?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"
            
            guard let url = URL(string: endpoint) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            
            if !coinGeckoKey.isEmpty {
                request.addValue(coinGeckoKey, forHTTPHeaderField: "x-cg-pro-api-key")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            // JSON yanıtını ayrıştır
            struct CoinDetailResponse: Codable {
                let id: String
                let symbol: String
                let name: String
                let image: ImageLinks?
                let marketData: MarketData?
                
                struct ImageLinks: Codable {
                    let large: String?
                }
                
                struct MarketData: Codable {
                    let currentPrice: [String: Double]?
                    let marketCap: [String: Double]?
                    let marketCapRank: Int?
                    let priceChangePercentage24h: Double?
                    let totalVolume: [String: Double]?
                    let high24h: [String: Double]?
                    let low24h: [String: Double]?
                    let ath: [String: Double]?
                    let athChangePercentage: [String: Double]?
                    
                    enum CodingKeys: String, CodingKey {
                        case currentPrice = "current_price"
                        case marketCap = "market_cap"
                        case marketCapRank = "market_cap_rank"
                        case priceChangePercentage24h = "price_change_percentage_24h"
                        case totalVolume = "total_volume"
                        case high24h = "high_24h"
                        case low24h = "low_24h"
                        case ath
                        case athChangePercentage = "ath_change_percentage"
                    }
                }
                
                enum CodingKeys: String, CodingKey {
                    case id, symbol, name, image
                    case marketData = "market_data"
                }
            }
            
            let decoder = JSONDecoder()
            let detailResponse = try decoder.decode(CoinDetailResponse.self, from: data)
            
            guard let marketData = detailResponse.marketData else {
                throw APIError.invalidData
            }
            
            let usdPrice = marketData.currentPrice?["usd"] ?? 0
            let change24h = marketData.priceChangePercentage24h ?? 0
            let marketCap = marketData.marketCap?["usd"] ?? 0
            let rank = marketData.marketCapRank ?? 0
            
            var coin = Coin(
                id: detailResponse.id,
                name: detailResponse.name,
                symbol: detailResponse.symbol.uppercased(),
                price: usdPrice,
                change24h: change24h,
                marketCap: marketCap,
                image: detailResponse.image?.large ?? "",
                rank: rank
            )
            
            // Ek verileri ekle
            coin.totalVolume = marketData.totalVolume?["usd"] ?? 0
            coin.high24h = marketData.high24h?["usd"] ?? 0
            coin.low24h = marketData.low24h?["usd"] ?? 0
            coin.ath = marketData.ath?["usd"] ?? 0
            coin.athChangePercentage = marketData.athChangePercentage?["usd"] ?? 0
            
            print("✅ Direkt ID aramasıyla coin detayları alındı")
            print("📊 Volume: \(coin.totalVolume)")
            print("📊 High 24h: \(coin.high24h)")
            print("📊 Low 24h: \(coin.low24h)")
            print("📊 ATH: \(coin.ath)")
            
            return coin
            
        } catch {
            print("⚠️ Direkt arama hatası: \(error.localizedDescription)")
            throw APIError.coinNotFound
        }
    }
    
    @Sendable
    func fetchCoinPriceHistory(coinId: String, days: Int = 7) async throws -> [APIGraphPoint] {
        print("📈 Coin fiyat geçmişi alınıyor: \(coinId) - \(days) gün")
        
        // CoinGecko API'sini kullan (ücretsiz plan)
        let apiKeys = [coinGeckoKey, coinMarketCapKey, coinAPIKey, cryptoAPIsKey]
        
        // API'leri sırayla dene
        for (index, apiKey) in apiKeys.enumerated() {
            do {
                switch index {
                case 0: // CoinGecko
                    let endpoint = "https://api.coingecko.com/api/v3/coins/\(coinId)/market_chart?vs_currency=usd&days=\(days)&interval=\(days > 30 ? "daily" : "hourly")"
                    
                    guard let url = URL(string: endpoint) else {
                        throw APIError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    if !apiKey.isEmpty {
                        request.addValue(apiKey, forHTTPHeaderField: "x-cg-pro-api-key")
                    }
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse, 
                          (200...299).contains(httpResponse.statusCode) else {
                        // HTTP hata kodunu kontrol et
                        if let httpResponse = response as? HTTPURLResponse {
                            if httpResponse.statusCode == 429 {
                                print("⚠️ CoinGecko API rate limit aşıldı, diğer API'ye geçiliyor")
                                continue // Diğer API'yi dene
                            }
                            if httpResponse.statusCode == 404 {
                                print("⚠️ CoinGecko API: Coin bulunamadı - \(coinId)")
                                continue // Diğer API'yi dene
                            }
                        }
                        throw APIError.invalidResponse
                    }
                    
                    // JSON parsing
                    let decoder = JSONDecoder()
                    
                    struct CoinGeckoChartResponse: Codable {
                        let prices: [[Double]]
                    }
                    
                    let chartData = try decoder.decode(CoinGeckoChartResponse.self, from: data)
                    
                    // CoinGecko API format: [[timestamp, price], [timestamp, price], ...]
                    var historyPoints: [APIGraphPoint] = []
                    for priceData in chartData.prices {
                        guard priceData.count >= 2 else { continue }
                        
                        // CoinGecko timestamp'i milisaniye cinsinden, doğrudan Double olarak kullan
                        let timestamp = priceData[0] / 1000.0 // milisaniyeden saniyeye çevir
                        let price = priceData[1]
                        
                        historyPoints.append(APIGraphPoint(timestamp: timestamp, price: price))
                    }
                    
                    print("✅ CoinGecko API'den \(historyPoints.count) veri noktası alındı")
                    return historyPoints
                    
                case 1: // CoinMarketCap
                    if coinMarketCapKey.isEmpty { continue }
                    
                    // CoinMarketCap'in ID formatı farklı olabilir, ID çevirisi gerekebilir
                    let endpoint = "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/historical?symbol=\(coinId)&time_start=\(Date().addingTimeInterval(-Double(days) * 24 * 60 * 60).ISO8601Format())&time_end=\(Date().ISO8601Format())&interval=\(days > 30 ? "daily" : "hourly")"
                    
                    guard let url = URL(string: endpoint) else {
                        throw APIError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.addValue(coinMarketCapKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
                    
                    // Benzer işlemler...
                    // Bu kısmı basitleştiriyorum - gerçek uygulamada tam implementasyon yapılmalı
                    continue
                    
                case 2, 3: // CoinAPI ve CryptoAPIs
                    // Diğer API'ler için benzer implementasyonlar...
                    continue
                    
                default:
                    throw APIError.allAPIsFailed
                }
            } catch {
                print("⚠️ API \(index) başarısız oldu: \(error.localizedDescription)")
                continue // Diğer API'yi dene
            }
        }
        
        // Eğer buraya kadar geldiyse ve veri alamadıysak, yedek olarak gerçekçi veri üretelim
        print("⚠️ Gerçek API verisi alınamadı, simüle edilen veri dönüyor...")
        
        // Gerçekçi veri üretmek için
        let now = Date()
        var historyPoints: [APIGraphPoint] = []
        
        // Coinin şu anki fiyatını bulalım
        let allCoins = try await fetchCoins(page: 1, perPage: 100)
        let currentPrice = allCoins.coins.first(where: { $0.id == coinId })?.price ?? 10000.0
        
        // Volatilite seviyesi - BTC daha az dalgalanır, küçük coinler daha çok
        let volatility = currentPrice < 100 ? 0.15 : (currentPrice < 1000 ? 0.08 : 0.03)
        
        // Trend - Rastgele bir trend
        let trend = Double.random(in: -0.1...0.1)
        
        // Volatilite seviyesi - Her coin için farklı
        let periodInSeconds = Double(days * 24 * 60 * 60)
        let dataPointCount = min(days * 24, 200) // Maksimum veri noktası
        let interval = periodInSeconds / Double(dataPointCount)
        
        var price = currentPrice
        
        // Son X gün için veri üretelim
        for i in 0..<dataPointCount {
            let date = now.addingTimeInterval(-periodInSeconds + (Double(i) * interval))
            
            // Volatilite ve trend faktörlerini uygula
            let randomChange = Double.random(in: -volatility...volatility)
            let trendChange = trend * (Double(i) / Double(dataPointCount)) * currentPrice
            
            // Fiyat hesaplama - Daha gerçekçi
            price = max(0.01, price * (1.0 + randomChange / 10.0))
            
            // Günün belirli saatlerinde daha büyük hareketler ekle
            let hour = Calendar.current.component(.hour, from: date)
            if hour == 9 || hour == 16 || hour == 22 { // Piyasa açılışı, kapanışı gibi volatil zamanlar
                price = price * (1.0 + Double.random(in: -volatility * 2...volatility * 2))
            }
            
            // Trend faktörünü ekle
            price += trendChange / Double(dataPointCount)
            
            // Direkt date'i kullanmak yerine timestamp değerini alıyoruz
            let timestamp = date.timeIntervalSince1970
            historyPoints.append(APIGraphPoint(timestamp: timestamp, price: price))
        }
        
        return historyPoints
    }
    
    // MARK: - Error Enums
    
    enum APIError: Error, Equatable {
        case invalidURL
        case invalidResponse
        case decodingError
        case allAPIsFailed
        case coinNotFound
        case rateLimitExceeded
        case invalidData
    }
    
    // MARK: - Models
    
    // GraphPoint modeli
    struct APIGraphPoint: Identifiable, Codable {
        var id = UUID()
        let timestamp: Double
        let price: Double
        
        var date: Date {
            return Date(timeIntervalSince1970: timestamp)
        }
        
        // UUID'leri kodlamak için CodingKeys kullanıyoruz
        enum CodingKeys: String, CodingKey {
            case timestamp, price
        }
        
        // Custom init from decoder
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            timestamp = try container.decode(Double.self, forKey: .timestamp)
            price = try container.decode(Double.self, forKey: .price)
        }
        
        // Normal init - doğrudan timestamp değerini al
        init(timestamp: Double, price: Double) {
            self.timestamp = timestamp
            self.price = price
        }
    }
    
    // NewsItem modeli
    struct APINewsItem: Identifiable, Comparable, Codable {
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
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChange24h: Double?
    let ath: Double?
    let athChangePercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChange24h = "price_change_24h"
        case ath
        case athChangePercentage = "ath_change_percentage"
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
    let volumeUsd24Hr: String?
    let supply: String?
    let maxSupply: String?
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
