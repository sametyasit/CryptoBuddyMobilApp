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
    
    // API yanıt tipi için bir tuple döndürelim
    struct APIResponse {
        let coins: [Coin]
        let source: String
        
        func first(where predicate: (Coin) -> Bool) -> Coin? {
            return coins.first(where: predicate)
        }
        
        var first: Coin? {
            return coins.first
        }
        
        var count: Int {
            return coins.count
        }
        
        subscript(index: Int) -> Coin {
            return coins[index]
        }
        
        func map<T>(_ transform: (Coin) -> T) -> [T] {
            return coins.map(transform)
        }
        
        func filter(_ isIncluded: (Coin) -> Bool) -> [Coin] {
            return coins.filter(isIncluded)
        }
    }
    
    // Önbellek için yapı
    private var coinCache: [String: (timestamp: Date, response: APIResponse)] = [:]
    private let cacheValidDuration: TimeInterval = 30 // 30 saniye
    
    func fetchCoins(page: Int, perPage: Int) async throws -> APIResponse {
        print("🔍 Fetching coins page \(page) with \(perPage) per page")
        
        // Önbellekten kontrol et
        let cacheKey = "coins_\(page)_\(perPage)"
        if let cached = coinCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheValidDuration {
            print("✅ Using cached coin data for page \(page)")
            return cached.response
        }
        
        var errors: [Error] = []
        
        // Try CoinGecko with a shorter timeout
        do {
            print("🔍 Trying CoinGecko API...")
            let coins = try await fetchCoinsFromCoinGecko(page: page, perPage: perPage)
            print("✅ CoinGecko success: \(coins.count) coins")
            let response = APIResponse(coins: coins, source: "CoinGecko")
            
            // Önbelleğe kaydet
            coinCache[cacheKey] = (Date(), response)
            return response
        } catch {
            print("❌ CoinGecko failed: \(error)")
            errors.append(error)
            
            // Try CoinStats with a shorter timeout
            do {
                print("🔍 Trying CoinStats API...")
                let coins = try await fetchCoinsFromCoinStats(limit: perPage, skip: (page - 1) * perPage)
                print("✅ CoinStats success: \(coins.count) coins")
                let response = APIResponse(coins: coins, source: "CoinStats")
                
                // Önbelleğe kaydet
                coinCache[cacheKey] = (Date(), response)
                return response
            } catch {
                print("❌ CoinStats failed: \(error)")
                errors.append(error)
                
                // Try CoinCap with a shorter timeout
                do {
                    print("🔍 Trying CoinCap API...")
                    let coins = try await fetchCoinsFromCoinCap(limit: perPage, offset: (page - 1) * perPage)
                    print("✅ CoinCap success: \(coins.count) coins")
                    let response = APIResponse(coins: coins, source: "CoinCap")
                    
                    // Önbelleğe kaydet
                    coinCache[cacheKey] = (Date(), response)
                    return response
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
        request.timeoutInterval = 5 // Timeout süresini 10 saniyeden 5 saniyeye düşür
        
        // Retry logic - Max 1 retry (reduced from 2)
        var attempts = 0
        let maxAttempts = 1
        
        while attempts <= maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if (200...299).contains(httpResponse.statusCode) {
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
                } else if httpResponse.statusCode == 429 {
                    // Rate limit aşıldı, yeniden dene
                    print("⚠️ CoinGecko rate limit exceeded, attempt \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        // Her yeni denemede bekleme süresini arttır
                        try await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5 saniye
                        continue
                    }
                    throw APIError.invalidResponse
                } else {
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinGecko request timed out, attempt \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5 saniye
                    continue
                }
                throw URLError(.timedOut)
            } catch {
                // Diğer hatalar için direkt throw et
                throw error
            }
        }
        
        // Tüm denemeler başarısız oldu
        throw APIError.invalidResponse
    }
    
    private func fetchCoinsFromCoinStats(limit: Int, skip: Int = 0) async throws -> [Coin] {
        var request = URLRequest(url: URL(string: "\(coinStatsAPI)/coins?limit=\(limit)&skip=\(skip)")!)
        request.setValue(coinStatsKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 5 // 15 saniyeden 5 saniyeye düşür
        
        // Retry logic - Max 1 retry
        var attempts = 0
        let maxAttempts = 1 // 2'den 1'e düşür
        
        while attempts <= maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if (200...299).contains(httpResponse.statusCode) {
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
                } else if httpResponse.statusCode == 429 {
                    // Rate limit aşıldı, yeniden dene
                    print("⚠️ CoinStats rate limit exceeded, attempt \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5 saniye
                        continue
                    }
                    throw APIError.invalidResponse
                } else {
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinStats request timed out, attempt \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5 saniye
                    continue
                }
                throw URLError(.timedOut)
            } catch {
                throw error
            }
        }
        
        throw APIError.invalidResponse
    }
    
    private func fetchCoinsFromCoinCap(limit: Int, offset: Int = 0) async throws -> [Coin] {
        let urlString = "\(coinCapURL)/assets?limit=\(limit)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5 // 15 saniyeden 5 saniyeye düşür
        
        // Retry logic - Max 1 retry
        var attempts = 0
        let maxAttempts = 1 // 2'den 1'e düşür
        
        while attempts <= maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if (200...299).contains(httpResponse.statusCode) {
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
                } else if httpResponse.statusCode == 429 {
                    // Rate limit aşıldı, yeniden dene
                    print("⚠️ CoinCap rate limit exceeded, attempt \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5 saniye
                        continue
                    }
                    throw APIError.invalidResponse
                } else {
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinCap request timed out, attempt \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5 saniye
                    continue
                }
                throw URLError(.timedOut)
            } catch {
                throw error
            }
        }
        
        throw APIError.invalidResponse
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
        var errors: [Error] = []
        
        // CryptoPanic
        do {
            print("📰 Fetching from CryptoPanic...")
            let cryptoPanicNews = try await fetchCryptoPanicNews()
            allNews.append(contentsOf: cryptoPanicNews)
            print("✅ CryptoPanic: Got \(cryptoPanicNews.count) news items")
        } catch {
            print("❌ CryptoPanic failed: \(error)")
            errors.append(error)
        }
        
        // NewsAPI
        do {
            print("📰 Fetching from NewsAPI...")
            let newsAPINews = try await fetchNewsAPINews()
            allNews.append(contentsOf: newsAPINews)
            print("✅ NewsAPI: Got \(newsAPINews.count) news items")
        } catch {
            print("❌ NewsAPI failed: \(error)")
            errors.append(error)
        }
        
        // CoinStats
        do {
            print("📰 Fetching from CoinStats...")
            let coinStatsNews = try await fetchCoinStatsNews()
            allNews.append(contentsOf: coinStatsNews)
            print("✅ CoinStats: Got \(coinStatsNews.count) news items")
        } catch {
            print("❌ CoinStats failed: \(error)")
            errors.append(error)
        }
        
        // En az bir kaynaktan veri aldıysak başarılı sayılır
        if !allNews.isEmpty {
            print("📰 Total news items: \(allNews.count)")
            return allNews.sorted(by: >)
        } else {
            // Hiçbir kaynaktan veri gelmezse hata fırlat
            print("❌❌❌ All news sources failed! Errors: \(errors)")
            if errors.isEmpty {
                throw APIError.invalidResponse
            } else {
                throw errors[0]
            }
        }
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
    
    // MARK: - Coin Detail Methods
    
    // Detay verisi için önbellek
    private var coinDetailCache: [String: (timestamp: Date, coin: Coin)] = [:]
    private let detailCacheValidDuration: TimeInterval = 120 // 2 dakika
    
    func fetchCoinDetails(coinId: String) async throws -> Coin {
        print("🔍 Fetching detailed information for coin ID: \(coinId)")
        
        // Önbellekten kontrol et
        if let cached = coinDetailCache[coinId],
           Date().timeIntervalSince(cached.timestamp) < detailCacheValidDuration {
            print("✅ Using cached detail data for coin: \(coinId)")
            return cached.coin
        }
        
        var errors: [Error] = []
        
        // Try CoinGecko first
        do {
            print("🔍 Trying CoinGecko API for details...")
            let coinDetail = try await fetchCoinDetailsFromCoinGecko(coinId: coinId)
            print("✅ CoinGecko detail success for \(coinId)")
            
            // Önbelleğe kaydet
            coinDetailCache[coinId] = (Date(), coinDetail)
            return coinDetail
        } catch {
            print("❌ CoinGecko detail failed: \(error)")
            errors.append(error)
            
            // Try backup sources
            do {
                print("🔍 Trying to get basic coin data as fallback...")
                let response = try await fetchCoins(page: 1, perPage: 100)
                if let coin = response.coins.first(where: { $0.id == coinId }) {
                    print("✅ Found basic coin data as fallback")
                    // Try to enhance with price history
                    do {
                        var enhancedCoin = coin
                        enhancedCoin.graphData = try await fetchCoinPriceHistory(coinId: coinId)
                        
                        // Önbelleğe kaydet (bu başarılı olursa)
                        coinDetailCache[coinId] = (Date(), enhancedCoin)
                        return enhancedCoin
                    } catch {
                        print("⚠️ Could not fetch price history: \(error)")
                        // Temel veriyi önbelleğe kaydet
                        coinDetailCache[coinId] = (Date(), coin)
                        return coin // Return basic coin data
                    }
                } else {
                    throw APIError.coinNotFound
                }
            } catch {
                print("❌ All detailed data sources failed: \(error)")
                throw APIError.allAPIsFailed
            }
        }
    }
    
    private func fetchCoinDetailsFromCoinGecko(coinId: String) async throws -> Coin {
        let detailUrlString = "\(coinGeckoURL)/coins/\(coinId)?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"
        let marketChartUrlString = "\(coinGeckoURL)/coins/\(coinId)/market_chart?vs_currency=usd&days=7"
        
        guard let detailUrl = URL(string: detailUrlString),
              let marketChartUrl = URL(string: marketChartUrlString) else {
            print("❌ Invalid URL for coinId: \(coinId)")
            throw APIError.invalidURL
        }
        
        // Timeout ve ağ hatalarını daha iyi yönetmek için URLSession yapılandırması
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8  // 15 saniye -> 8 saniye
        config.timeoutIntervalForResource = 15 // 30 saniye -> 15 saniye
        let session = URLSession(configuration: config)
        
        let detailRequest = URLRequest(url: detailUrl)
        let chartRequest = URLRequest(url: marketChartUrl)
        
        // İstek durumunu izleme
        print("🔍 Requesting detail data from: \(detailUrl.absoluteString)")
        print("🔍 Requesting chart data from: \(marketChartUrl.absoluteString)")
        
        // Paralel istek yapma yerine sıralı istek yapalım
        do {
            // İlk önce detay verilerini alalım
            let (detailData, detailHttpResponse) = try await session.data(for: detailRequest)
            
            // Detay HTTP yanıtını kontrol ediyoruz
            guard let detailHttpResponse = detailHttpResponse as? HTTPURLResponse else {
                print("❌ Invalid detail response type")
                throw APIError.invalidResponse
            }
            
            // Hata durumunda HTTP durum kodunu yazdır
            if !(200...299).contains(detailHttpResponse.statusCode) {
                print("❌ Detail HTTP error: \(detailHttpResponse.statusCode)")
                throw APIError.invalidResponse
            }
            
            // JSON çözme hatalarını daha iyi yakalama
            let decoder = JSONDecoder()
            
            // Detay verisini ayrıştırma
            let detailResponse = try decoder.decode(CoinGeckoDetailResponse.self, from: detailData)
            
            // Create base coin object
            var coin = Coin(
                id: detailResponse.id,
                name: detailResponse.name,
                symbol: detailResponse.symbol.uppercased(),
                price: detailResponse.marketData.currentPrice["usd"] ?? 0,
                change24h: detailResponse.marketData.priceChangePercentage24h ?? 0,
                marketCap: detailResponse.marketData.marketCap["usd"] ?? 0,
                image: detailResponse.image.large,
                rank: detailResponse.marketCapRank ?? 0
            )
            
            // Add additional data
            coin.totalVolume = detailResponse.marketData.totalVolume["usd"] ?? 0
            coin.high24h = detailResponse.marketData.high24h["usd"] ?? 0
            coin.low24h = detailResponse.marketData.low24h["usd"] ?? 0
            coin.priceChange24h = detailResponse.marketData.priceChange24h ?? 0
            coin.ath = detailResponse.marketData.ath["usd"] ?? 0
            coin.athChangePercentage = detailResponse.marketData.athChangePercentage["usd"] ?? 0
            coin.description = detailResponse.description["en"] ?? ""
            
            // Add links
            if !detailResponse.links.homepage.isEmpty {
                coin.website = detailResponse.links.homepage.first ?? ""
            }
            if let twitter = detailResponse.links.twitterScreenName {
                coin.twitter = "https://twitter.com/\(twitter)"
            }
            if let reddit = detailResponse.links.subredditUrl {
                coin.reddit = reddit
            }
            if let repos = detailResponse.links.reposUrl.github, !repos.isEmpty {
                coin.github = repos.first ?? ""
            }
            
            // Önce temel detayları döndürüp, sonra arka planda chart verilerini alıp güncelleme yapalım
            // Bu sayede kullanıcı daha hızlı yüklenen bir ekran görecek
            
            // Detay verilerinin asenkron olarak güncellenmesi için başka bir Task başlat
            Task {
                do {
                    let (chartData, chartResponse) = try await session.data(for: chartRequest)
                    
                    if let chartHttpResponse = chartResponse as? HTTPURLResponse, 
                       (200...299).contains(chartHttpResponse.statusCode) {
                        do {
                            let chartData = try decoder.decode(CoinGeckoChartResponse.self, from: chartData)
                            let graphData = chartData.prices.map { dataPoint in
                                GraphPoint(timestamp: dataPoint[0] / 1000, price: dataPoint[1])
                            }
                            
                            // Grafiğin yüklenmesinden sonra önbelleği güncelleyelim
                            if let cachedCoin = coinDetailCache[coin.id]?.coin {
                                var updatedCoin = cachedCoin
                                updatedCoin.graphData = graphData
                                coinDetailCache[coin.id] = (Date(), updatedCoin)
                            }
                            
                            print("✅ Chart data loaded successfully with \(graphData.count) points")
                        } catch {
                            print("⚠️ Failed to parse chart data: \(error)")
                        }
                    }
                } catch {
                    print("⚠️ Failed to load chart data: \(error)")
                }
            }
            
            return coin
        } catch {
            print("❌ Error fetching coin details: \(error)")
            throw error
        }
    }
    
    func fetchCoinPriceHistory(coinId: String, days: Int = 7) async throws -> [GraphPoint] {
        print("📈 Fetching price history for \(coinId) over \(days) days")
        var errors: [Error] = []
        
        // Try CoinGecko
        do {
            let chartData = try await fetchCoinGeckoChartData(coinId: coinId, days: days)
            return chartData
        } catch {
            errors.append(error)
            print("❌ CoinGecko chart failed: \(error)")
            
            // Try CoinCap as fallback
            do {
                let chartData = try await fetchCoinCapChartData(coinId: coinId, days: days)
                return chartData
            } catch {
                errors.append(error)
                print("❌ CoinCap chart failed: \(error)")
                
                // If both failed, throw an error
                throw APIError.allAPIsFailed
            }
        }
    }
    
    private func fetchCoinGeckoChartData(coinId: String, days: Int) async throws -> [GraphPoint] {
        let urlString = "\(coinGeckoURL)/coins/\(coinId)/market_chart?vs_currency=usd&days=\(days)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let chartResponse = try decoder.decode(CoinGeckoChartResponse.self, from: data)
        
        return chartResponse.prices.map { dataPoint in
            GraphPoint(timestamp: dataPoint[0] / 1000, price: dataPoint[1])
        }
    }
    
    private func fetchCoinCapChartData(coinId: String, days: Int) async throws -> [GraphPoint] {
        // Convert days to milliseconds
        let interval = "d1" // d1 = daily data points
        let urlString = "\(coinCapURL)/assets/\(coinId)/history?interval=\(interval)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let chartResponse = try decoder.decode(CoinCapHistoryResponse.self, from: data)
        
        return chartResponse.data.map { dataPoint in
            let timestamp = Double(dataPoint.time) / 1000
            let price = Double(dataPoint.priceUsd) ?? 0
            return GraphPoint(timestamp: timestamp, price: price)
        }
    }
    
    // MARK: - Response Models
    
    // CoinGecko detailed coin response
    struct CoinGeckoDetailResponse: Codable {
        let id: String
        let symbol: String
        let name: String
        let description: [String: String]
        let image: CoinGeckoImage
        let marketCapRank: Int?
        let marketData: MarketData
        let links: Links
        
        enum CodingKeys: String, CodingKey {
            case id, symbol, name, description, image, links
            case marketCapRank = "market_cap_rank"
            case marketData = "market_data"
        }
        
        struct CoinGeckoImage: Codable {
            let thumb: String
            let small: String
            let large: String
        }
        
        struct MarketData: Codable {
            let currentPrice: [String: Double]
            let ath: [String: Double]
            let athChangePercentage: [String: Double]
            let marketCap: [String: Double]
            let totalVolume: [String: Double]
            let high24h: [String: Double]
            let low24h: [String: Double]
            let priceChange24h: Double?
            let priceChangePercentage24h: Double?
            
            enum CodingKeys: String, CodingKey {
                case currentPrice = "current_price"
                case ath
                case athChangePercentage = "ath_change_percentage"
                case marketCap = "market_cap"
                case totalVolume = "total_volume"
                case high24h
                case low24h
                case priceChange24h = "price_change_24h"
                case priceChangePercentage24h = "price_change_percentage_24h"
            }
        }
        
        struct Links: Codable {
            let homepage: [String]
            let twitterScreenName: String?
            let subredditUrl: String?
            let reposUrl: ReposUrl
            
            enum CodingKeys: String, CodingKey {
                case homepage
                case twitterScreenName = "twitter_screen_name"
                case subredditUrl = "subreddit_url"
                case reposUrl = "repos_url"
            }
            
            struct ReposUrl: Codable {
                let github: [String]?
            }
        }
    }
    
    // CoinGecko chart data response
    struct CoinGeckoChartResponse: Codable {
        let prices: [[Double]]
    }
    
    // CoinCap history response
    struct CoinCapHistoryResponse: Codable {
        let data: [DataPoint]
        
        struct DataPoint: Codable {
            let priceUsd: String
            let time: Int64
        }
    }
}

// MARK: - Models

enum APIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case decodingError
    case allAPIsFailed
    case coinNotFound
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