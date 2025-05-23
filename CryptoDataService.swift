import Foundation

protocol CryptoDataServiceDelegate: AnyObject {
    func didUpdateCoins(_ coins: [Coin])
    func didUpdateCoin(_ coin: Coin)
    func didReceiveError(_ error: Error)
    func didUpdateConnectionStatus(isConnected: Bool)
}

class CryptoDataService {
    static let shared = CryptoDataService()
    
    private var timer: Timer?
    private var lastFetchTime: Date?
    private var coinDataCache: [String: Coin] = [:] // Cache for coin data
    private var currentCoins: [Coin] = []
    
    weak var delegate: CryptoDataServiceDelegate?
    
    private init() {
        // Setup WebSocket delegate
        WebSocketManager.shared.delegate = self
    }
    
    // Start real-time data service
    func startService() {
        // Connect to WebSocket
        WebSocketManager.shared.connect()
        
        // Initial data fetch from REST API
        fetchInitialData()
        
        // Setup backup timer for fallback if WebSocket fails
        setupBackupTimer()
    }
    
    // Stop service
    func stopService() {
        WebSocketManager.shared.disconnect()
        timer?.invalidate()
        timer = nil
    }
    
    // Fetch initial data from REST API
    private func fetchInitialData() {
        CoinNetworkManager.shared.fetchCoins(perPage: 100) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let coins):
                self.currentCoins = coins
                
                // Update cache with fetched coins
                for coin in coins {
                    self.coinDataCache[coin.symbol.uppercased()] = coin
                }
                
                // Notify delegate
                DispatchQueue.main.async {
                    self.delegate?.didUpdateCoins(coins)
                }
                
                // Subscribe to WebSocket updates for these coins
                let symbols = coins.map { $0.symbol }
                WebSocketManager.shared.subscribeToCoins(symbols: symbols)
                
                self.lastFetchTime = Date()
                
                // Önden logo yükleme işlemini başlat
                self.prefetchLogosForCoins(coins)
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.delegate?.didReceiveError(error)
                }
                // If REST API fails, rely on scheduled timer to retry
            }
        }
    }
    
    // Tüm coinlerin logolarını ön belleğe al
    private func prefetchLogosForCoins(_ coins: [Coin]) {
        // Paralel olarak hem FastAPI hem de ImageCacheManager kullan
        FastCryptoAPIClient.shared.prefetchAllCoinLogos(coins: coins)
        
        // En iyi logo URL'lerini bulmak için arkaplanda çalış
        let symbols = coins.map { $0.symbol }
        FastCryptoAPIClient.shared.findBestLogoURLs(for: symbols) { [weak self] bestLogoURLs in
            // Bulunan en iyi logo URLlerini CoinTableViewCell'de kullanabilmek için sakla
            self?.storeBestLogoURLs(bestLogoURLs)
        }
    }
    
    // En iyi logo URL'lerini sakla ve güncelle
    private var bestLogoURLsCache = [String: String]()
    private let logoURLsLock = NSLock()
    
    private func storeBestLogoURLs(_ logoURLs: [String: String]) {
        logoURLsLock.lock()
        defer { logoURLsLock.unlock() }
        
        for (symbol, url) in logoURLs {
            bestLogoURLsCache[symbol.uppercased()] = url
        }
    }
    
    /// Bir sembol için en iyi logo URL'sini döndürür
    func getBestLogoURL(for symbol: String) -> String? {
        logoURLsLock.lock()
        defer { logoURLsLock.unlock() }
        
        return bestLogoURLsCache[symbol.uppercased()]
    }
    
    // Fetch data for a specific coin detail
    func fetchCoinDetail(id: String, completion: @escaping (Result<CoinDetail, NetworkError>) -> Void) {
        CoinNetworkManager.shared.fetchCoinDetail(id: id, completion: completion)
    }
    
    // Setup backup timer for REST API fetches if WebSocket fails
    private func setupBackupTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Time.coinRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only fetch if WebSocket connection is not active or if last fetch was too long ago
            let shouldFetch = !WebSocketManager.shared.isConnected || 
                              self.lastFetchTime == nil || 
                              Date().timeIntervalSince(self.lastFetchTime!) > Constants.Time.coinRefreshInterval * 2
            
            if shouldFetch {
                self.fetchInitialData()
            }
        }
    }
    
    // Update an individual coin in the cache and notify delegate
    private func updateCoinPrice(symbol: String, price: Double, changePercent: Double) {
        let upperSymbol = symbol.uppercased()
        
        // If we have this coin in cache, update it
        if var coin = coinDataCache[upperSymbol] {
            // Update the price and percent change
            coin.currentPrice = price
            coin.priceChangePercentage = changePercent
            
            // Update the cache
            coinDataCache[upperSymbol] = coin
            
            // Update in the coins array
            if let index = currentCoins.firstIndex(where: { $0.symbol.uppercased() == upperSymbol }) {
                currentCoins[index] = coin
                
                // Notify delegate
                DispatchQueue.main.async {
                    self.delegate?.didUpdateCoin(coin)
                }
            }
        }
    }
    
    // Access the current coins list
    var coins: [Coin] {
        return currentCoins
    }
}

// MARK: - WebSocketManagerDelegate
extension CryptoDataService: WebSocketManagerDelegate {
    func didReceiveCoinUpdate(coin: Coin) {
        // Add to cache
        coinDataCache[coin.symbol.uppercased()] = coin
        
        // Update in coins array if it exists
        if let index = currentCoins.firstIndex(where: { $0.id == coin.id }) {
            currentCoins[index] = coin
            
            // Notify delegate
            DispatchQueue.main.async {
                self.delegate?.didUpdateCoin(coin)
            }
        }
    }
    
    func didReceivePriceUpdate(symbol: String, price: Double, changePercent: Double) {
        updateCoinPrice(symbol: symbol, price: price, changePercent: changePercent)
    }
    
    func didDisconnect(error: Error?) {
        DispatchQueue.main.async {
            self.delegate?.didUpdateConnectionStatus(isConnected: false)
            
            if let error = error {
                self.delegate?.didReceiveError(error)
            }
        }
    }
    
    func didConnect() {
        DispatchQueue.main.async {
            self.delegate?.didUpdateConnectionStatus(isConnected: true)
            
            // Subscribe to current coins
            let symbols = self.currentCoins.map { $0.symbol }
            WebSocketManager.shared.subscribeToCoins(symbols: symbols)
        }
    }
} 