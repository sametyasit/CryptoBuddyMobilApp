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
        
        // CoinGecko requires an API key for higher rate limits, but free tier doesn't need one
        // If you have a Pro API key, you can add it here
        // request.setValue("YOUR_API_KEY", forHTTPHeaderField: "X-CoinGecko-Api-Key")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(.serverError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.serverError("Invalid response")))
                return
            }
            
            // CoinGecko rate limit handling
            if httpResponse.statusCode == 429 {
                completion(.failure(.serverError("API Rate limit exceeded. Please try again later.")))
                return
            }
            
            guard httpResponse.statusCode == 200, let data = data else {
                completion(.failure(.serverError("Status code: \(httpResponse.statusCode)")))
                return
            }
            
            do {
                let coins = try JSONDecoder().decode([Coin].self, from: data)
                completion(.success(coins))
            } catch {
                print("Decoding error: \(error)")
                print("Response body: \(String(data: data, encoding: .utf8) ?? "Unable to print data")")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
    
    // Tek bir coin'in detaylarını getiren fonksiyon
    func fetchCoinDetail(id: String, completion: @escaping (Result<CoinDetail, NetworkError>) -> Void) {
        let urlString = "\(baseURL)/coins/\(id)?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
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
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
    
    // Görsel indirme fonksiyonu - önbelleğe alır
    let imageCache = NSCache<NSString, UIImage>()
    
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Önbellekte varsa oradan al
        if let cachedImage = imageCache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data),
                  error == nil else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Önbelleğe kaydet
            self.imageCache.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
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