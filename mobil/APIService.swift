import Foundation
import Combine
import Network
import SwiftUI

class APIService {
    static let shared = APIService()
    
    private let coinGeckoURL = "https://api.coingecko.com/api/v3"
    private let binanceURL = "https://api.binance.com/api/v3"
    private let coinCapURL = "https://api.coincap.io/v2"
    private let cryptoPanicURL = "https://cryptopanic.com/api/v1"
    private let newsAPIURL = "https://newsapi.org/v2"
    private let coinStatsAPI = "https://api.coinstats.app/public/v1"
    private let coinMarketCapURL = "https://pro-api.coinmarketcap.com/v1"
    
    // Yeni eklenen alternatif API'ler
    private let cryptoCompareURL = "https://min-api.cryptocompare.com/data"
    private let coinLayerURL = "https://api.coinlayer.com"
    private let coinPaprikaURL = "https://api.coinpaprika.com/v1"
    
    // Add your API keys here
    private let coinGeckoKey = "CG-Ld9nYXMFXXHFBGBKASqQj12H"
    private let cryptoPanicKey = "ac278e4633ac912593fdf81fae619aa4fe7bd8d1"
    private let newsAPIKey = "d718195189714c7f87c9aa19fabc0169"
    private let coinStatsKey = "nygWaH29Z4o0H6DizGxfm0S2/3MT2Ud46fQojcGGAR8="
    private let coinMarketCapKey = "b54bcf4d-1bca-4e8e-9a24-22ff2c3d462c"
    
    // Yeni eklenen API anahtarları
    private let cryptoCompareKey = "4c47e8b9732aabe507ac0be25e1daf2f0d63dd7277bb46e1438b141b8cf2dd2c"
    private let coinLayerKey = "5a46adb51e8e2d3cdb96fb2ba88a3500"
    // CoinPaprika ücretsiz key gerektirmiyor
    
    // EnvironmentObject için bir referans
    private var networkMonitor: NetworkMonitorViewModel?
    
    private var newsTimer: Timer?
    private var newsUpdateCallback: (([NewsItem]) -> Void)?
    
    private init() {}
    
    // Environment Object'i ayarlamak için metod
    func configure(with networkMonitor: NetworkMonitorViewModel) {
        self.networkMonitor = networkMonitor
    }
    
    // Ağ bağlantısını kontrol et
    private var isConnectedToNetwork: Bool {
        // Eğer networkMonitor yoksa varsayılan olarak bağlı kabul et
        return networkMonitor?.isConnected ?? true
    }
    
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
    private let cacheValidDuration: TimeInterval = 60 // 30 saniyeden 60 saniyeye çıkarıldı
    
    @Sendable
    func fetchCoins(page: Int, perPage: Int) async throws -> APIResponse {
        print("🔍 Fetching coins page \(page) with \(perPage) per page")
        
        // Önbellekten kontrol et
        let cacheKey = "coins_\(page)_\(perPage)"
        if let cached = coinCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheValidDuration {
            print("✅ Önbellekten veri kullanılıyor (sayfa \(page))")
            return cached.response
        }
        
        var errors: [Error] = []
        
        // 1. Try CoinGecko API
        do {
            print("🔍 CoinGecko API deneniyor...")
            let coins = try await fetchCoinsFromCoinGecko(page: page, perPage: perPage)
            print("✅ CoinGecko başarılı: \(coins.count) coin")
            let response = APIResponse(coins: coins, source: "CoinGecko")
            
            // Önbelleğe kaydet
            coinCache[cacheKey] = (Date(), response)
            return response
        } catch {
            print("❌ CoinGecko başarısız: \(error)")
            errors.append(error)
            
            // 2. Try CoinMarketCap API
            do {
                print("🔍 CoinMarketCap API deneniyor...")
                let start = (page - 1) * perPage + 1
                let coins = try await fetchCoinsFromCoinMarketCap(limit: perPage, start: start)
                print("✅ CoinMarketCap başarılı: \(coins.count) coin")
                let response = APIResponse(coins: coins, source: "CoinMarketCap")
                
                // Önbelleğe kaydet
                coinCache[cacheKey] = (Date(), response)
                return response
            } catch {
                print("❌ CoinMarketCap başarısız: \(error)")
                errors.append(error)
                
                // 3. Try CoinStats API
                do {
                    print("🔍 CoinStats API deneniyor...")
                    let coins = try await fetchCoinsFromCoinStats(limit: perPage, skip: (page - 1) * perPage)
                    print("✅ CoinStats başarılı: \(coins.count) coin")
                    let response = APIResponse(coins: coins, source: "CoinStats")
                    
                    // Önbelleğe kaydet
                    coinCache[cacheKey] = (Date(), response)
                    return response
                } catch {
                    print("❌ CoinStats başarısız: \(error)")
                    errors.append(error)
                    
                    // 4. Try CoinCap API
                    do {
                        print("🔍 CoinCap API deneniyor...")
                        let coins = try await fetchCoinsFromCoinCap(limit: perPage, offset: (page - 1) * perPage)
                        print("✅ CoinCap başarılı: \(coins.count) coin")
                        let response = APIResponse(coins: coins, source: "CoinCap")
                        
                        // Önbelleğe kaydet
                        coinCache[cacheKey] = (Date(), response)
                        return response
                    } catch {
                        print("❌ CoinCap başarısız: \(error)")
                        errors.append(error)
                        
                        // 5. Try CryptoCompare API (Yeni eklenen)
                        do {
                            print("🔍 CryptoCompare API deneniyor...")
                            let coins = try await fetchCoinsFromCryptoCompare(limit: perPage)
                            print("✅ CryptoCompare başarılı: \(coins.count) coin")
                            let response = APIResponse(coins: coins, source: "CryptoCompare")
                            
                            // Önbelleğe kaydet
                            coinCache[cacheKey] = (Date(), response)
                            return response
                        } catch {
                            print("❌ CryptoCompare başarısız: \(error)")
                            errors.append(error)
                            
                            // 6. Try CoinLayer API (Yeni eklenen)
                            do {
                                print("🔍 CoinLayer API deneniyor...")
                                let coins = try await fetchCoinsFromCoinLayer()
                                print("✅ CoinLayer başarılı: \(coins.count) coin")
                                let response = APIResponse(coins: coins, source: "CoinLayer")
                                
                                // Önbelleğe kaydet
                                coinCache[cacheKey] = (Date(), response)
                                return response
                            } catch {
                                print("❌ CoinLayer başarısız: \(error)")
                                errors.append(error)
                                
                                // 7. Try CoinPaprika API (Yeni eklenen)
                                do {
                                    print("🔍 CoinPaprika API deneniyor...")
                                    let coins = try await fetchCoinsFromCoinPaprika(limit: perPage)
                                    print("✅ CoinPaprika başarılı: \(coins.count) coin")
                                    let response = APIResponse(coins: coins, source: "CoinPaprika")
                                    
                                    // Önbelleğe kaydet
                                    coinCache[cacheKey] = (Date(), response)
                                    return response
                                } catch {
                                    print("❌ CoinPaprika başarısız: \(error)")
                                    errors.append(error)
                                    
                                    // Tüm API'ler başarısız oldu
                                    print("❌❌❌ Tüm API kaynakları başarısız!")
                                    print("🚨 Hatalar: \(errors.map { "\($0)" }.joined(separator: ", "))")
                                    throw APIError.allAPIsFailed
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func fetchCoinsFromCoinGecko(page: Int, perPage: Int) async throws -> [Coin] {
        // API yanıtını daha detaylı inceleyelim
        print("🔄 CoinGecko API isteği başlatılıyor - Sayfa: \(page), Adet: \(perPage)")
        
        // CoinGecko için ücretsiz API endpoint'i 
        // Not: Ücretsiz plan rate limitleri var, Pro için farklı endpoint kullanılır
        let urlString = "\(coinGeckoURL)/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=\(perPage)&page=\(page)&sparkline=false&price_change_percentage=24h"
        
        guard let url = URL(string: urlString) else {
            print("❌ CoinGecko: Geçersiz URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        // Print network connectivity status
        print("🌐 Ağ bağlantısı var mı: \(isConnectedToNetwork ? "Evet" : "Hayır")")
        
        if !isConnectedToNetwork {
            print("❌ CoinGecko: Ağ bağlantısı yok!")
            throw URLError(.notConnectedToInternet)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15 // 10 saniyeden 15 saniyeye çıkardık
        
        // API anahtarı ekleme - ücretsiz plan API anahtarı kullanmıyor ama Pro için gerekli
        if !coinGeckoKey.isEmpty {
            request.addValue(coinGeckoKey, forHTTPHeaderField: "x-cg-pro-api-key")
        }
        
        // User-Agent ekle - API'nin isteği bloke etmemesi için
        request.addValue("CryptoBuddy/1.0", forHTTPHeaderField: "User-Agent")
        
        // Debugging
        print("🔍 CoinGecko isteği: \(urlString)")
        
        // Retry logic - Max 2 retries
        var attempts = 0
        let maxAttempts = 2 
        
        while attempts <= maxAttempts {
            do {
                print("⏱️ CoinGecko API isteği gönderiliyor. Deneme: \(attempts + 1)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CoinGecko: HTTP yanıtı alınamadı")
                    throw APIError.invalidResponse
                }
                
                print("🌐 CoinGecko API HTTP Status: \(httpResponse.statusCode)")
                
                // Başlıkları göster
                if let headers = httpResponse.allHeaderFields as? [String: String] {
                    print("📋 HTTP Başlıklar: \(headers)")
                    
                    // Rate limit bilgisini kontrol et
                    if let rateLimit = headers["x-ratelimit-limit"],
                       let rateRemaining = headers["x-ratelimit-remaining"] {
                        print("📊 Rate Limit: \(rateLimit), Kalan: \(rateRemaining)")
                    }
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    let decoder = JSONDecoder()
                    
                    // JSON verisini yazdırın (debug için)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📝 İlk 200 karakter: \(String(jsonString.prefix(200)))")
                    }
                    
                    do {
                        let coins = try decoder.decode([CoinGeckoData].self, from: data)
                        print("✅ CoinGecko başarılı: \(coins.count) coin çekildi")
                        
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
                    } catch {
                        print("❌ CoinGecko: JSON decode hatası: \(error)")
                        print("❌ JSON: \(String(data: data, encoding: .utf8) ?? "Veri okunamadı")")
                        throw APIError.decodingError
                    }
                } else if httpResponse.statusCode == 429 {
                    // Rate limit aşıldı, yeniden dene
                    print("⚠️ CoinGecko rate limit aşıldı, deneme \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        // Her yeni denemede bekleme süresini arttır
                        let waitTime = Double(attempts) * 2.0 // Artan bekleme süresi
                        print("⏱️ \(waitTime) saniye bekleniyor...")
                        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000)) // 2, 4 saniye...
                        continue
                    }
                    throw APIError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("❌ CoinGecko: API anahtarı hatası veya erişim reddedildi: \(httpResponse.statusCode)")
                    // Hata mesajını yazdır
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("🚫 Hata mesajı: \(errorText)")
                    }
                    throw APIError.invalidResponse
                } else {
                    print("❌ CoinGecko: Beklenmeyen HTTP durum kodu: \(httpResponse.statusCode)")
                    // Hata mesajını yazdır
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("🚫 Hata mesajı: \(errorText)")
                    }
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinGecko: İstek zaman aşımına uğradı, deneme \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000)) // 1 saniye bekle
                    continue
                }
                throw URLError(.timedOut)
            } catch URLError.notConnectedToInternet {
                print("❌ CoinGecko: İnternet bağlantısı yok!")
                throw URLError(.notConnectedToInternet)
            } catch {
                // Spesifik hata mesajlarını yazdır
                print("❌ CoinGecko: Hata: \(error.localizedDescription)")
                // Diğer hatalar için direkt throw et
                throw error
            }
        }
        
        // Tüm denemeler başarısız oldu
        print("❌❌ CoinGecko: Tüm denemeler başarısız")
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
        // CoinCap API anahtarı - güncel bir anahtar ile değiştirin
        let coinCapApiKey = "26549c5e-3e55-4e90-b622-fe68338fcaf7"
        
        let urlString = "\(coinCapURL)/assets?limit=\(limit)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            print("❌ CoinCap: Geçersiz URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // API anahtarını ekle
        if !coinCapApiKey.isEmpty {
            request.addValue(coinCapApiKey, forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 10 // Daha uzun timeout
        
        print("🔍 CoinCap isteği: \(urlString)")
        
        // Retry logic - Max 2 retries
        var attempts = 0
        let maxAttempts = 2
        
        while attempts <= maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CoinCap: HTTP yanıtı alınamadı")
                    throw APIError.invalidResponse
                }
                
                print("🌐 CoinCap API HTTP Status: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    let decoder = JSONDecoder()
                    
                    // JSON verisini yazdırın (debug için)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📝 CoinCap yanıt (ilk 100): \(String(jsonString.prefix(100)))")
                    }
                    
                    do {
                        let coinCapResponse = try decoder.decode(CoinCapResponse.self, from: data)
                        print("✅ CoinCap başarılı: \(coinCapResponse.data.count) coin çekildi")
                        
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
                    } catch {
                        print("❌ CoinCap: JSON decode hatası: \(error)")
                        throw APIError.decodingError
                    }
                } else if httpResponse.statusCode == 429 {
                    // Rate limit aşıldı, yeniden dene
                    print("⚠️ CoinCap rate limit aşıldı, deneme \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        let waitTime = Double(attempts) * 2.0
                        print("⏱️ \(waitTime) saniye bekleniyor...")
                        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                        continue
                    }
                    throw APIError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("❌ CoinCap: API anahtarı hatası veya erişim reddedildi: \(httpResponse.statusCode)")
                    // Hata mesajını yazdır
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("🚫 Hata mesajı: \(errorText)")
                    }
                    throw APIError.invalidResponse
                } else {
                    print("❌ CoinCap: Beklenmeyen HTTP durum kodu: \(httpResponse.statusCode)")
                    // Hata mesajını yazdır
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("🚫 Hata mesajı: \(errorText)")
                    }
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinCap: İstek zaman aşımına uğradı, deneme \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                    continue
                }
                throw URLError(.timedOut)
            } catch {
                print("❌ CoinCap: Hata: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌❌ CoinCap: Tüm denemeler başarısız")
        throw APIError.invalidResponse
    }
    
    private func fetchCoinsFromCoinMarketCap(limit: Int, start: Int = 1) async throws -> [Coin] {
        let urlString = "\(coinMarketCapURL)/cryptocurrency/listings/latest"
        
        guard let url = URL(string: urlString) else {
            print("❌ CoinMarketCap: Geçersiz URL: \(urlString)")
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
            "limit": "\(limit)",
            "convert": "USD"
        ]
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        if let paramURL = components.url {
            request.url = paramURL
        }
        
        print("🔍 CoinMarketCap isteği: \(request.url?.absoluteString ?? urlString)")
        
        // Retry logic
        var attempts = 0
        let maxAttempts = 2
        
        while attempts <= maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CoinMarketCap: HTTP yanıtı alınamadı")
                    throw APIError.invalidResponse
                }
                
                print("🌐 CoinMarketCap API HTTP Status: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    // JSON verisini yazdırın (debug için)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📝 CoinMarketCap yanıt (ilk 100): \(String(jsonString.prefix(100)))")
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        let coinMarketCapResponse = try decoder.decode(CoinMarketCapResponse.self, from: data)
                        print("✅ CoinMarketCap başarılı: \(coinMarketCapResponse.data.count) coin çekildi")
                        
                        return coinMarketCapResponse.data.map { coinData in
                            let usdQuote = coinData.quote["USD"] ?? CoinMarketCapQuote(price: 0, volume24h: 0, percentChange24h: 0, marketCap: 0)
                            
                            return Coin(
                                id: "\(coinData.id)".lowercased(), // CoinMarketCap farklı ID formatı kullanır
                                name: coinData.name,
                                symbol: coinData.symbol,
                                price: usdQuote.price,
                                change24h: usdQuote.percentChange24h,
                                marketCap: usdQuote.marketCap,
                                image: "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coinData.id).png",
                                rank: coinData.cmcRank
                            )
                        }
                    } catch {
                        print("❌ CoinMarketCap: JSON decode hatası: \(error)")
                        throw APIError.decodingError
                    }
                } else if httpResponse.statusCode == 429 {
                    print("⚠️ CoinMarketCap rate limit aşıldı, deneme \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        let waitTime = Double(attempts) * 2.0
                        print("⏱️ \(waitTime) saniye bekleniyor...")
                        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                        continue
                    }
                    throw APIError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("❌ CoinMarketCap: API anahtarı hatası: \(httpResponse.statusCode)")
                    // Hata mesajını yazdır
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("🚫 Hata mesajı: \(errorText)")
                    }
                    throw APIError.invalidResponse
                } else {
                    print("❌ CoinMarketCap: Beklenmeyen HTTP durum kodu: \(httpResponse.statusCode)")
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("🚫 Hata mesajı: \(errorText)")
                    }
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinMarketCap: İstek zaman aşımına uğradı, deneme \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                    continue
                }
                throw URLError(.timedOut)
            } catch {
                print("❌ CoinMarketCap: Hata: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌❌ CoinMarketCap: Tüm denemeler başarısız")
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
    
    @Sendable
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
    
    @Sendable
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
                        coinDetailCache[coin.id] = (Date(), enhancedCoin)
                        return enhancedCoin
                    } catch {
                        print("⚠️ Could not fetch price history: \(error)")
                        // Temel veriyi önbelleğe kaydet
                        coinDetailCache[coin.id] = (Date(), coin)
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
    
    @Sendable
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
    
    // MARK: - Yeni API metodları
    
    private func fetchCoinsFromCryptoCompare(limit: Int) async throws -> [Coin] {
        print("🔄 CryptoCompare API isteği başlatılıyor - Limit: \(limit)")
        
        // CryptoCompare için en çok piyasa değerine sahip kripto paraları getiren endpoint
        let urlString = "\(cryptoCompareURL)/top/mktcapfull?limit=\(limit)&tsym=USD"
        
        guard let url = URL(string: urlString) else {
            print("❌ CryptoCompare: Geçersiz URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        // Ağ bağlantısını kontrol et
        print("🌐 Ağ bağlantısı var mı: \(isConnectedToNetwork ? "Evet" : "Hayır")")
        
        if !isConnectedToNetwork {
            print("❌ CryptoCompare: Ağ bağlantısı yok!")
            throw URLError(.notConnectedToInternet)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        // API anahtarını ekle
        request.addValue(cryptoCompareKey, forHTTPHeaderField: "authorization")
        
        // User-Agent ekle
        request.addValue("CryptoBuddy/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔍 CryptoCompare isteği: \(urlString)")
        
        // Retry logic - Max 2 retries
        var attempts = 0
        let maxAttempts = 2
        
        while attempts <= maxAttempts {
            do {
                print("⏱️ CryptoCompare API isteği gönderiliyor. Deneme: \(attempts + 1)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CryptoCompare: HTTP yanıtı alınamadı")
                    throw APIError.invalidResponse
                }
                
                print("🌐 CryptoCompare API HTTP Status: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    // Debug için JSON verisini yazdır
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📝 İlk 200 karakter: \(String(jsonString.prefix(200)))")
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(CryptoCompareResponse.self, from: data)
                        print("✅ CryptoCompare başarılı: \(response.Data.count) coin çekildi")
                        
                        return response.Data.map { coinData in
                            let price = coinData.RAW?.USD?.PRICE ?? 0
                            let change24h = coinData.RAW?.USD?.CHANGEPCT24HOUR ?? 0
                            let marketCap = coinData.RAW?.USD?.MKTCAP ?? 0
                            
                            return Coin(
                                id: coinData.CoinInfo.Name.lowercased(),
                                name: coinData.CoinInfo.FullName,
                                symbol: coinData.CoinInfo.Name,
                                price: price,
                                change24h: change24h,
                                marketCap: marketCap,
                                image: "https://www.cryptocompare.com\(coinData.CoinInfo.ImageUrl)",
                                rank: coinData.CoinInfo.SortOrder
                            )
                        }
                    } catch {
                        print("❌ CryptoCompare: JSON decode hatası: \(error)")
                        print("❌ JSON: \(String(data: data, encoding: .utf8) ?? "Veri okunamadı")")
                        throw APIError.decodingError
                    }
                } else if httpResponse.statusCode == 429 {
                    print("⚠️ CryptoCompare rate limit aşıldı, deneme \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(2_000_000_000))
                        continue
                    }
                    throw APIError.rateLimitExceeded
                } else {
                    print("❌ CryptoCompare: Beklenmeyen HTTP durum kodu: \(httpResponse.statusCode)")
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CryptoCompare: İstek zaman aşımına uğradı, deneme \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                    continue
                }
                throw URLError(.timedOut)
            } catch URLError.notConnectedToInternet {
                print("❌ CryptoCompare: İnternet bağlantısı yok!")
                throw URLError(.notConnectedToInternet)
            } catch {
                print("❌ CryptoCompare: Hata: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌❌ CryptoCompare: Tüm denemeler başarısız")
        throw APIError.invalidResponse
    }
    
    private func fetchCoinsFromCoinLayer() async throws -> [Coin] {
        print("🔄 CoinLayer API isteği başlatılıyor")
        
        // CoinLayer için tüm kripto paraları getiren endpoint
        let urlString = "\(coinLayerURL)/live?access_key=\(coinLayerKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ CoinLayer: Geçersiz URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        // Ağ bağlantısını kontrol et
        print("🌐 Ağ bağlantısı var mı: \(isConnectedToNetwork ? "Evet" : "Hayır")")
        
        if !isConnectedToNetwork {
            print("❌ CoinLayer: Ağ bağlantısı yok!")
            throw URLError(.notConnectedToInternet)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        print("🔍 CoinLayer isteği: \(urlString)")
        
        // Retry logic
        var attempts = 0
        let maxAttempts = 2
        
        while attempts <= maxAttempts {
            do {
                print("⏱️ CoinLayer API isteği gönderiliyor. Deneme: \(attempts + 1)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CoinLayer: HTTP yanıtı alınamadı")
                    throw APIError.invalidResponse
                }
                
                print("🌐 CoinLayer API HTTP Status: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📝 İlk 200 karakter: \(String(jsonString.prefix(200)))")
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(CoinLayerResponse.self, from: data)
                        
                        if !response.success {
                            print("❌ CoinLayer başarısız yanıt: \(response.error?.info ?? "Bilinmeyen hata")")
                            throw APIError.invalidResponse
                        }
                        
                        var coins: [Coin] = []
                        var rank = 1
                        
                        for (symbol, price) in response.rates {
                            // CoinLayer sadece fiyat bilgisi veriyor, diğer bilgileri varsayılan değerlerle dolduralım
                            coins.append(Coin(
                                id: symbol.lowercased(),
                                name: symbol,
                                symbol: symbol,
                                price: price,
                                change24h: 0, // CoinLayer'da değişim verisi yok
                                marketCap: 0, // CoinLayer'da market cap verisi yok
                                image: "https://assets.coinlayer.com/icons/\(symbol.lowercased()).png",
                                rank: rank
                            ))
                            rank += 1
                        }
                        
                        print("✅ CoinLayer başarılı: \(coins.count) coin çekildi")
                        return coins
                    } catch {
                        print("❌ CoinLayer: JSON decode hatası: \(error)")
                        print("❌ JSON: \(String(data: data, encoding: .utf8) ?? "Veri okunamadı")")
                        throw APIError.decodingError
                    }
                } else {
                    print("❌ CoinLayer: Beklenmeyen HTTP durum kodu: \(httpResponse.statusCode)")
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinLayer: İstek zaman aşımına uğradı, deneme \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                    continue
                }
                throw URLError(.timedOut)
            } catch {
                print("❌ CoinLayer: Hata: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌❌ CoinLayer: Tüm denemeler başarısız")
        throw APIError.invalidResponse
    }
    
    private func fetchCoinsFromCoinPaprika(limit: Int) async throws -> [Coin] {
        print("🔄 CoinPaprika API isteği başlatılıyor - Limit: \(limit)")
        
        // CoinPaprika için tüm kripto paraları getiren endpoint
        let urlString = "\(coinPaprikaURL)/tickers"
        
        guard let url = URL(string: urlString) else {
            print("❌ CoinPaprika: Geçersiz URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        // Ağ bağlantısını kontrol et
        print("🌐 Ağ bağlantısı var mı: \(isConnectedToNetwork ? "Evet" : "Hayır")")
        
        if !isConnectedToNetwork {
            print("❌ CoinPaprika: Ağ bağlantısı yok!")
            throw URLError(.notConnectedToInternet)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        print("🔍 CoinPaprika isteği: \(urlString)")
        
        // Retry logic
        var attempts = 0
        let maxAttempts = 2
        
        while attempts <= maxAttempts {
            do {
                print("⏱️ CoinPaprika API isteği gönderiliyor. Deneme: \(attempts + 1)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CoinPaprika: HTTP yanıtı alınamadı")
                    throw APIError.invalidResponse
                }
                
                print("🌐 CoinPaprika API HTTP Status: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📝 İlk 200 karakter: \(String(jsonString.prefix(200)))")
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        let coins = try decoder.decode([CoinPaprikaData].self, from: data)
                        
                        // Limit uygula
                        let limitedCoins = Array(coins.prefix(limit))
                        
                        print("✅ CoinPaprika başarılı: \(limitedCoins.count) coin çekildi")
                        
                        return limitedCoins.map { coinData in
                            return Coin(
                                id: coinData.id,
                                name: coinData.name,
                                symbol: coinData.symbol,
                                price: coinData.quotes.USD.price,
                                change24h: coinData.quotes.USD.percentChange24h,
                                marketCap: coinData.quotes.USD.marketCap,
                                image: "https://static.coinpaprika.com/coin/\(coinData.id)/logo.png",
                                rank: coinData.rank
                            )
                        }
                    } catch {
                        print("❌ CoinPaprika: JSON decode hatası: \(error)")
                        print("❌ JSON: \(String(data: data, encoding: .utf8) ?? "Veri okunamadı")")
                        throw APIError.decodingError
                    }
                } else if httpResponse.statusCode == 429 {
                    print("⚠️ CoinPaprika rate limit aşıldı, deneme \(attempts+1)/\(maxAttempts+1)")
                    attempts += 1
                    if attempts <= maxAttempts {
                        try await Task.sleep(nanoseconds: UInt64(2_000_000_000))
                        continue
                    }
                    throw APIError.rateLimitExceeded
                } else {
                    print("❌ CoinPaprika: Beklenmeyen HTTP durum kodu: \(httpResponse.statusCode)")
                    throw APIError.invalidResponse
                }
            } catch URLError.timedOut {
                print("⚠️ CoinPaprika: İstek zaman aşımına uğradı, deneme \(attempts+1)/\(maxAttempts+1)")
                attempts += 1
                if attempts <= maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                    continue
                }
                throw URLError(.timedOut)
            } catch URLError.notConnectedToInternet {
                print("❌ CoinPaprika: İnternet bağlantısı yok!")
                throw URLError(.notConnectedToInternet)
            } catch {
                print("❌ CoinPaprika: Hata: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌❌ CoinPaprika: Tüm denemeler başarısız")
        throw APIError.invalidResponse
    }
    
    // MARK: - Yeni API Modelleri
    
    // CryptoCompare API Modelleri
    struct CryptoCompareResponse: Codable {
        let Data: [CryptoCompareData]
        let Message: String
        let type: Int
        
        enum CodingKeys: String, CodingKey {
            case Data, Message
            case type = "Type"
        }
    }

    struct CryptoCompareData: Codable {
        let CoinInfo: CryptoCoinInfo
        let RAW: CryptoRawData?
        let DISPLAY: CryptoDisplayData?
    }

    struct CryptoCoinInfo: Codable {
        let Id: String
        let Name: String
        let FullName: String
        let ImageUrl: String
        let SortOrder: Int
    }

    struct CryptoRawData: Codable {
        let USD: CryptoUsdData?
    }

    struct CryptoUsdData: Codable {
        let PRICE: Double
        let CHANGEPCT24HOUR: Double
        let MKTCAP: Double
    }

    struct CryptoDisplayData: Codable {
        let USD: CryptoUsdDisplayData?
    }

    struct CryptoUsdDisplayData: Codable {
        let PRICE: String
        let CHANGEPCT24HOUR: String
        let MKTCAP: String
    }
    
    // CoinLayer API Modelleri
    struct CoinLayerResponse: Codable {
        let success: Bool
        let terms: String?
        let privacy: String?
        let timestamp: Int?
        let target: String?
        let rates: [String: Double]
        let error: CoinLayerError?
    }

    struct CoinLayerError: Codable {
        let code: Int
        let type: String
        let info: String
    }
    
    // CoinPaprika API Modelleri
    struct CoinPaprikaData: Codable {
        let id: String
        let name: String
        let symbol: String
        let rank: Int
        let quotes: CoinPaprikaQuotes
    }

    struct CoinPaprikaQuotes: Codable {
        let USD: CoinPaprikaUSD
    }

    struct CoinPaprikaUSD: Codable {
        let price: Double
        let marketCap: Double
        let percentChange24h: Double
        
        enum CodingKeys: String, CodingKey {
            case price
            case marketCap = "market_cap"
            case percentChange24h = "percent_change_24h"
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
}

// MARK: - Models

enum APIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case decodingError
    case allAPIsFailed
    case coinNotFound
    case rateLimitExceeded
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

struct CoinStatisticsResult: Codable {
    let type: Int
} 