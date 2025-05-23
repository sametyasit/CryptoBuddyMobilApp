import Foundation
import UIKit

// Network durumları için enum
enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
}

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}
    
    // Haberleri getiren fonksiyon
    func fetchNews(completion: @escaping (Result<[News], NetworkError>) -> Void) {
        guard let url = URL(string: Constants.API.turkishNewsURL) else {
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
                let newsResponse = try JSONDecoder().decode(NewsResponse.self, from: data)
                completion(.success(newsResponse.Data))
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