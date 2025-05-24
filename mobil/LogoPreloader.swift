import Foundation
import UIKit
import SwiftUI

/// Logo ön yükleme işlemleri için gelişmiş yardımcı sınıf
class LogoPreloader {
    // Singleton
    static let shared = LogoPreloader()
    
    // Önbelleğe alınan logolar için durum
    private var preloadedLogos: [String: Bool] = [:]
    private var isPreloading = false
    
    // Logo önbelleğe alındığında bildirim için notify token
    private let notificationCenter = NotificationCenter.default
    static let logoPreloadedNotification = Notification.Name("LogoPreloaded")
    
    // Sabit yaygın crypto paraların URL'leri
    private let commonCryptoLogos: [String: String] = [
        "bitcoin": "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
        "ethereum": "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
        "tether": "https://assets.coingecko.com/coins/images/325/large/Tether.png",
        "binancecoin": "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png",
        "ripple": "https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png",
        "cardano": "https://assets.coingecko.com/coins/images/975/large/cardano.png",
        "solana": "https://assets.coingecko.com/coins/images/4128/large/solana.png",
        "polkadot": "https://assets.coingecko.com/coins/images/12171/large/polkadot.png",
        "dogecoin": "https://assets.coingecko.com/coins/images/5/large/dogecoin.png",
        "shiba-inu": "https://assets.coingecko.com/coins/images/11939/large/shiba.png"
    ]
    
    private init() {
        // Başlangıçta popüler coin logolarını yükle
        preloadPopularLogos()
    }
    
    /// Uygulama başladığında çağrılmalı - popüler coinlerin logolarını hemen yükler
    private func preloadPopularLogos() {
        Task.detached(priority: .high) {
            for (id, url) in self.commonCryptoLogos {
                guard let imageUrl = URL(string: url) else { continue }
                
                // Önbellek anahtarı
                let cacheKey = "\(id)_logo"
                
                // Eğer ImageCache'de zaten varsa atla
                if ImageCache.shared.getImage(forKey: cacheKey) != nil {
                    self.preloadedLogos[id] = true
                    continue
                }
                
                // Değilse indir ve önbelleğe al
                do {
                    let (data, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = UIImage(data: data) {
                        // Ana thread'de önbelleğe ekle
                        await MainActor.run {
                            ImageCache.shared.setImage(image, forKey: cacheKey)
                            self.preloadedLogos[id] = true
                            
                            // Bildirim gönder
                            self.notificationCenter.post(
                                name: LogoPreloader.logoPreloadedNotification,
                                object: id
                            )
                        }
                    }
                } catch {
                    print("⚠️ Logo önbelleğe alınamadı: \(id), hata: \(error.localizedDescription)")
                }
            }
            print("✅ Popüler coinlerin logoları önbelleğe alındı!")
        }
    }
    
    /// Coin listesi için logoları önceden yükle
    /// - Parameter coins: Yüklenecek coinler
    func preloadLogos(for coins: [Coin]) {
        guard !isPreloading else { return }
        isPreloading = true
        
        // Paralel ve hızlı yükleme için task grubu
        Task.detached(priority: .userInitiated) {
            // İlk 50 coini öncelikli olarak yükle
            let priorityCoins = Array(coins.prefix(50))
            
            await withTaskGroup(of: Void.self) { group in
                for coin in priorityCoins {
                    group.addTask {
                        await self.preloadLogo(for: coin)
                    }
                }
            }
            
            self.isPreloading = false
            print("✅ Coin logoları başarıyla önbelleğe alındı!")
        }
    }
    
    /// Tek bir coin için logo yükleme
    private func preloadLogo(for coin: Coin) async {
        // Eğer zaten yüklendiyse tekrar yükleme
        if preloadedLogos[coin.id] == true {
            return
        }
        
        // Önbellek anahtarı
        let cacheKey = "\(coin.id)_\(coin.symbol)_logo"
        
        // Zaten önbellekte var mı kontrol et
        if ImageCache.shared.getImage(forKey: cacheKey) != nil {
            preloadedLogos[coin.id] = true
            return
        }
        
        // Alternatif URL'ler
        let possibleURLs = [
            coin.image,
            "https://assets.coingecko.com/coins/images/\(coin.id)/small/\(coin.symbol.lowercased()).png",
            "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coin.id).png",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/32/color/\(coin.symbol.lowercased()).png"
        ]
        
        // URL'leri sırayla dene
        for urlString in possibleURLs {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    // Önbelleğe ekle
                    await MainActor.run {
                        ImageCache.shared.setImage(image, forKey: cacheKey)
                        preloadedLogos[coin.id] = true
                        
                        // Bildirim gönder
                        notificationCenter.post(
                            name: LogoPreloader.logoPreloadedNotification,
                            object: coin.id
                        )
                    }
                    return // Başarılı
                }
            } catch {
                continue // Bu URL başarısız, bir sonrakini dene
            }
        }
    }
} 