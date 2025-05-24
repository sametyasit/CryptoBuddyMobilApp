import Foundation
import UIKit
import SwiftUI

/// Logo önbellekleme için global helper - tüm uygulamadan erişim için
let imageCacheHelper = ImageCacheHelperImpl()

/// Logo yükleme ve önbellekleme için yardımcı sınıf
class ImageCacheHelperImpl {
    /// Coin logolarını toplu olarak önbelleğe alma
    /// - Parameter coins: Önbelleğe alınacak coinler
    func preloadCoinLogos(for coins: [Coin]) {
        // İlk 50 coini önbelleğe al - kullanıcı deneyimini iyileştirmek için
        let topCoins = Array(coins.prefix(50))
        
        print("📱 Logo önbelleğe alma başlatılıyor - \(topCoins.count) coin için")
        
        // Düşük öncelikli bir kuyrukta arkaplanda yükle
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            for coin in topCoins {
                // Logoları yüklerken bir dizi farklı olası URL'yi dene
                let possibleURLs = [
                    coin.image, // Ana URL
                    "https://assets.coingecko.com/coins/images/\(coin.id)/small/\(coin.symbol.lowercased()).png",
                    "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coin.id).png",
                    "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/32/color/\(coin.symbol.lowercased()).png"
                ]
                
                // Her coin için bir kez başarılı olunca diğerine geç
                var logoLoaded = false
                
                for urlString in possibleURLs where !logoLoaded {
                    // Boş veya geçersiz URL'leri atla
                    guard !urlString.isEmpty, let url = URL(string: urlString) else { continue }
                    
                    // Önbellek anahtarı
                    let cacheKey = "\(coin.id)_\(coin.symbol)_logo"
                    
                    // Zaten önbellekte var mı kontrol et
                    if ImageCache.shared.getImage(forKey: cacheKey) != nil {
                        logoLoaded = true
                        break
                    }
                    
                    // Değilse, indir ve önbelleğe al
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                        if let data = data, let image = UIImage(data: data) {
                            // Başarılı yüklemeyi önbelleğe kaydet
                            ImageCache.shared.setImage(image, forKey: cacheKey)
                            logoLoaded = true
                        }
                        semaphore.signal()
                    }
                    
                    task.resume()
                    
                    // En fazla 2 saniye bekle ve sonraki URL'ye geç
                    _ = semaphore.wait(timeout: .now() + 2)
                    
                    if logoLoaded {
                        break
                    }
                }
            }
            
            print("📱 Logo önbelleğe alma tamamlandı - \(topCoins.count) coin için")
        }
    }
} 