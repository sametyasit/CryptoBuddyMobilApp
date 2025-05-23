import Foundation

class FastCryptoAPIClient {
    static let shared = FastCryptoAPIClient()
    
    private init() {}
    
    // API endpoints for faster data sources
    private let binanceAPIURL = "https://api.binance.com/api/v3/ticker/24hr"
    private let coinbaseAPIURL = "https://api.coinbase.com/v2/exchange-rates?currency=USD"
    private let krakenAPIURL = "https://api.kraken.com/0/public/Ticker"
    
    // Cache para eşleme (CoinGecko ID'leri -> Exchange sembolleri)
    private let symbolMapping: [String: String] = [
        "bitcoin": "BTC",
        "ethereum": "ETH",
        "ripple": "XRP",
        "bitcoin-cash": "BCH",
        "litecoin": "LTC",
        "cardano": "ADA",
        "polkadot": "DOT",
        "binancecoin": "BNB",
        "stellar": "XLM",
        "chainlink": "LINK",
        "dogecoin": "DOGE",
        "usd-coin": "USDC",
        "uniswap": "UNI",
        "aave": "AAVE",
        "solana": "SOL",
        "tether": "USDT"
    ]
    
    // Faster alternative to fetch top coin prices (Binance API)
    func fetchTopCoinPrices(completion: @escaping (Result<[String: (price: Double, change: Double)], Error>) -> Void) {
        guard let url = URL(string: binanceAPIURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    completion(.failure(NetworkError.decodingError))
                    return
                }
                
                var results: [String: (price: Double, change: Double)] = [:]
                
                for item in jsonArray {
                    guard let symbol = item["symbol"] as? String,
                          let priceString = item["lastPrice"] as? String,
                          let changeString = item["priceChangePercent"] as? String,
                          let price = Double(priceString),
                          let change = Double(changeString) else {
                        continue
                    }
                    
                    // Extract base symbol (remove USDT, BTC, etc. suffix)
                    let baseSymbol: String
                    if symbol.hasSuffix("USDT") {
                        baseSymbol = String(symbol.dropLast(4))
                    } else if symbol.hasSuffix("USD") {
                        baseSymbol = String(symbol.dropLast(3))
                    } else {
                        continue // Skip non-USD pairs
                    }
                    
                    results[baseSymbol] = (price, change)
                }
                
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Update existing coin data with faster APIs
    func updateCoinsWithFastData(coins: [Coin], completion: @escaping ([Coin]) -> Void) {
        fetchTopCoinPrices { result in
            switch result {
            case .success(let priceData):
                var updatedCoins = coins
                
                for (index, coin) in coins.enumerated() {
                    let symbol = coin.symbol.uppercased()
                    
                    if let data = priceData[symbol] {
                        // Update the coin with the latest price data
                        updatedCoins[index].currentPrice = data.price
                        updatedCoins[index].priceChangePercentage = data.change
                        updatedCoins[index].lastUpdated = Date()
                    }
                }
                
                completion(updatedCoins)
                
            case .failure(let error):
                print("Failed to update with fast data: \(error)")
                completion(coins) // Return original coins on error
            }
        }
    }
    
    // Fetch single coin price from Binance (faster than CoinGecko for popular coins)
    func fetchSingleCoinPrice(symbol: String, completion: @escaping (Result<(price: Double, change: Double), Error>) -> Void) {
        let upperSymbol = symbol.uppercased() + "USDT"
        let urlString = "https://api.binance.com/api/v3/ticker/24hr?symbol=\(upperSymbol)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let priceString = json["lastPrice"] as? String,
                      let changeString = json["priceChangePercent"] as? String,
                      let price = Double(priceString),
                      let change = Double(changeString) else {
                    completion(.failure(NetworkError.decodingError))
                    return
                }
                
                completion(.success((price, change)))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Try multiple APIs in parallel and return the fastest response
    func fetchMultiSourceCoinPrice(coinId: String, symbol: String, completion: @escaping (Result<Double, Error>) -> Void) {
        let group = DispatchGroup()
        var price: Double?
        var latestError: Error?
        
        // Use Binance API
        group.enter()
        fetchSingleCoinPrice(symbol: symbol) { result in
            switch result {
            case .success(let data):
                price = data.price
            case .failure(let error):
                latestError = error
            }
            group.leave()
        }
        
        // CoinGecko API fallback is handled in the CoinNetworkManager
        
        group.notify(queue: .main) {
            if let price = price {
                completion(.success(price))
            } else {
                completion(.failure(latestError ?? NetworkError.noData))
            }
        }
    }
    
    // Coin logo bilgilerini toplu şekilde getirir - çeşitli kaynaklardan
    func prefetchAllCoinLogos(coins: [Coin]) {
        // En öncelikli coinlerden başla
        let priorityCoins = Array(coins.prefix(30))
        
        // İki ayrı öncelik kuyruğu oluştur
        let highPriorityQueue = DispatchQueue.global(qos: .userInitiated)
        let normalPriorityQueue = DispatchQueue.global(qos: .utility)
        
        // Öncelikli coinlerin logolarını hemen yükle
        highPriorityQueue.async {
            for coin in priorityCoins {
                ImageCacheManager.shared.loadCoinImage(from: coin.image, symbol: coin.symbol) { _ in
                    // Yükleme tamamlandı, önbelleğe alındı
                }
            }
        }
        
        // Geri kalan coinlerin logolarını daha düşük öncelikte yükle
        if coins.count > 30 {
            let remainingCoins = Array(coins.suffix(from: 30))
            normalPriorityQueue.async {
                for coin in remainingCoins {
                    ImageCacheManager.shared.loadCoinImage(from: coin.image, symbol: coin.symbol) { _ in
                        // Yükleme tamamlandı, önbelleğe alındı
                    }
                    
                    // CPU kullanımını optimize etmek için kısa bir bekleme ekle
                    if remainingCoins.count > 50 {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }
        }
    }
    
    // Kripto logoları için en iyi URLleri bulan fonksiyon
    func findBestLogoURLs(for symbols: [String], completion: @escaping ([String: String]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var result = [String: String]()
        let resultLock = NSLock()
        
        // İhtiyaç halinde yeni logo kaynakları ekleyebiliriz
        let logoSources = [
            "https://s2.coinmarketcap.com/static/img/coins/64x64/TOKEN.png",
            "https://cryptoicons.org/api/icon/TOKEN/200",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/TOKEN.png"
        ]
        
        for symbol in symbols {
            dispatchGroup.enter()
            
            // Sembol için en iyi logo URL'sini bul
            checkLogoSources(for: symbol, sources: logoSources) { bestURL in
                if let bestURL = bestURL {
                    resultLock.lock()
                    result[symbol] = bestURL
                    resultLock.unlock()
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(result)
        }
    }
    
    // Logo kaynakları arasından en iyi çalışanı bulma
    private func checkLogoSources(for symbol: String, sources: [String], completion: @escaping (String?) -> Void) {
        let lowerSymbol = symbol.lowercased()
        var sourcesToCheck = sources.map { $0.replacingOccurrences(of: "TOKEN", with: lowerSymbol) }
        
        checkNextLogoSource(sources: sourcesToCheck, index: 0) { workingURL in
            completion(workingURL)
        }
    }
    
    // Logo kaynaklarını sırayla dene
    private func checkNextLogoSource(sources: [String], index: Int, completion: @escaping (String?) -> Void) {
        guard index < sources.count else {
            completion(nil)
            return
        }
        
        let urlString = sources[index]
        guard let url = URL(string: urlString) else {
            // Bu kaynak geçersiz, sonrakini dene
            checkNextLogoSource(sources: sources, index: index + 1, completion: completion)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data, !data.isEmpty,
               error == nil {
                // Logo bulundu
                completion(urlString)
            } else {
                // Bu kaynak çalışmadı, sonrakini dene
                self.checkNextLogoSource(sources: sources, index: index + 1, completion: completion)
            }
        }
        task.resume()
    }
}

// Extension to CryptoDataService to integrate fast API
extension CryptoDataService {
    // Use fast API alongside WebSocket for redundancy
    func updateWithFastAPI() {
        FastCryptoAPIClient.shared.updateCoinsWithFastData(coins: currentCoins) { [weak self] updatedCoins in
            guard let self = self else { return }
            
            // Update local cache
            self.currentCoins = updatedCoins
            
            // Update cache
            for coin in updatedCoins {
                self.coinDataCache[coin.symbol.uppercased()] = coin
            }
            
            // Notify delegate of updates
            DispatchQueue.main.async {
                self.delegate?.didUpdateCoins(updatedCoins)
            }
        }
    }
} 