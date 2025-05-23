import Foundation
import UIKit

class CoinNetworkManager {
    static let shared = CoinNetworkManager()
    
    private init() {}
    
    // CoinGecko API URL
    private let baseURL = "https://api.coingecko.com/api/v3"
    
    // Coinleri getiren fonksiyon
    func fetchCoins(timeFrame: TimeFrame = .day, currency: String = "usd", perPage: Int = 100, page: Int = 1, completion: @escaping (Result<[Coin], NetworkError>) -> Void) {
        let urlString = "\(baseURL)/coins/markets?vs_currency=\(currency)&order=market_cap_desc&per_page=\(perPage)&page=\(page)&sparkline=false&price_change_percentage=\(timeFrame.parameterValue)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15 // Daha uzun timeout ekle
        request.cachePolicy = .returnCacheDataElseLoad // Önbelleği kullan
        
        // CoinGecko requires an API key for higher rate limits, but free tier doesn't need one
        // If you have a Pro API key, you can add it here
        // request.setValue("YOUR_API_KEY", forHTTPHeaderField: "X-CoinGecko-Api-Key")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                // Hata durumunda önbellekteki verileri dene
                if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)) {
                    do {
                        let coins = try JSONDecoder().decode([Coin].self, from: cachedResponse.data)
                        print("API hatası: \(error.localizedDescription), önbellekteki veriler kullanılıyor")
                        completion(.success(coins))
                    } catch {
                        completion(.failure(.serverError(error.localizedDescription)))
                    }
                    return
                }
                
                completion(.failure(.serverError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.serverError("Invalid response")))
                return
            }
            
            // CoinGecko rate limit handling
            if httpResponse.statusCode == 429 {
                // Rate limit aşıldığında önbellekteki verileri kullan
                if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)) {
                    do {
                        let coins = try JSONDecoder().decode([Coin].self, from: cachedResponse.data)
                        print("API rate limit aşıldı, önbellekteki veriler kullanılıyor")
                        completion(.success(coins))
                    } catch {
                        completion(.failure(.serverError("API Rate limit exceeded. Please try again later.")))
                    }
                    return
                }
                
                completion(.failure(.serverError("API Rate limit exceeded. Please try again later.")))
                return
            }
            
            guard httpResponse.statusCode == 200, let data = data else {
                completion(.failure(.serverError("Status code: \(httpResponse.statusCode)")))
                return
            }
            
            do {
                let coins = try JSONDecoder().decode([Coin].self, from: data)
                
                // Coin verileri içinde logolar için URL'leri ön yükle
                self.preloadCoinImages(coins)
                
                completion(.success(coins))
            } catch {
                print("Decoding error: \(error)")
                print("Response body: \(String(data: data, encoding: .utf8) ?? "Unable to print data")")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
    
    // Logoları ön yükleme fonksiyonu
    private func preloadCoinImages(_ coins: [Coin]) {
        // En yüksek piyasa değerine sahip ilk 20 coinin logosunu önden yükle
        let topCoins = Array(coins.prefix(20))
        
        DispatchQueue.global(qos: .utility).async {
            for coin in topCoins {
                ImageCacheManager.shared.loadCoinImage(from: coin.image, symbol: coin.symbol) { _ in }
            }
        }
    }
    
    // Tek bir coin'in detaylarını getiren fonksiyon
    func fetchCoinDetail(id: String, completion: @escaping (Result<CoinDetail, NetworkError>) -> Void) {
        let urlString = "\(baseURL)/coins/\(id)?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .returnCacheDataElseLoad
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                // Hata durumunda önbellekteki verileri dene
                if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)) {
                    do {
                        let coinDetail = try JSONDecoder().decode(CoinDetail.self, from: cachedResponse.data)
                        print("API hatası: \(error.localizedDescription), önbellekteki detaylar kullanılıyor")
                        completion(.success(coinDetail))
                    } catch {
                        completion(.failure(.serverError(error.localizedDescription)))
                    }
                    return
                }
                
                completion(.failure(.serverError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let coinDetail = try JSONDecoder().decode(CoinDetail.self, from: data)
                completion(.success(coinDetail))
                
                // Detay logolarını ön belleğe al
                if let thumbUrl = URL(string: coinDetail.image.thumb) {
                    URLSession.shared.dataTask(with: thumbUrl) { _, _, _ in }.resume()
                }
                if let smallUrl = URL(string: coinDetail.image.small) {
                    URLSession.shared.dataTask(with: smallUrl) { _, _, _ in }.resume()
                }
                if let largeUrl = URL(string: coinDetail.image.large) {
                    URLSession.shared.dataTask(with: largeUrl) { _, _, _ in }.resume()
                }
                
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
    
    // Görsel indirme fonksiyonu - önbelleğe alır
    let imageCache = NSCache<NSString, UIImage>()
    private let concurrentImageQueue = DispatchQueue(label: "com.cryptobuddy.imageQueue", attributes: .concurrent)
    private var ongoingDownloads = [String: URLSessionDataTask]()
    private let ongoingDownloadsLock = NSLock()
    
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Önbellekte varsa hemen döndür
        if let cachedImage = imageCache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Devam eden indirme kontrolü - aynı URL için birden fazla indirme olmaması için
        ongoingDownloadsLock.lock()
        if let existingTask = ongoingDownloads[urlString] {
            ongoingDownloadsLock.unlock()
            // Aynı URL için zaten indirme işlemi yapılıyor, tamamlanınca tüm bekleyenlere bildir
            existingTask.cancel() // Eski görevi iptal et, yeni bir tane oluştur
        }
        ongoingDownloadsLock.unlock()
        
        // Yeni indirme görevi oluştur
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // İndirme tamamlandı, kaydını kaldır
            self.ongoingDownloadsLock.lock()
            self.ongoingDownloads.removeValue(forKey: urlString)
            self.ongoingDownloadsLock.unlock()
            
            if let error = error {
                print("Logo indirme hatası: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            self.concurrentImageQueue.async {
                if let image = UIImage(data: data) {
                    // Önbelleğe kaydet
                    self.imageCache.setObject(image, forKey: urlString as NSString)
                    
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
        
        // Yeni indirme görevini kaydet ve başlat
        ongoingDownloadsLock.lock()
        ongoingDownloads[urlString] = task
        ongoingDownloadsLock.unlock()
        task.resume()
    }
}

// Coin Detay modeli
struct CoinDetail: Codable {
    let id: String
    let symbol: String
    let name: String
    let description: [String: String]
    let image: CoinImage
    let marketData: MarketData
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, description, image
        case marketData = "market_data"
        case lastUpdated = "last_updated"
    }
    
    struct CoinImage: Codable {
        let thumb: String
        let small: String
        let large: String
    }
    
    struct MarketData: Codable {
        let currentPrice: [String: Double]
        let marketCap: [String: Double]
        let totalVolume: [String: Double]
        let high24h: [String: Double]
        let low24h: [String: Double]
        let priceChangePercentage24h: Double?
        let priceChangePercentage7d: Double?
        let priceChangePercentage30d: Double?
        let priceChangePercentage1y: Double?
        
        enum CodingKeys: String, CodingKey {
            case currentPrice = "current_price"
            case marketCap = "market_cap"
            case totalVolume = "total_volume"
            case high24h = "high_24h"
            case low24h = "low_24h"
            case priceChangePercentage24h = "price_change_percentage_24h"
            case priceChangePercentage7d = "price_change_percentage_7d"
            case priceChangePercentage30d = "price_change_percentage_30d"
            case priceChangePercentage1y = "price_change_percentage_1y"
        }
    }
} 