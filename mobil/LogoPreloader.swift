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
        
        let coinSymbol = coin.symbol.lowercased()
        let coinIdLower = coin.id.lowercased()
        
        // Alternatif URL'ler - Daha kapsamlı ve güncel
        let possibleURLs = [
            coin.image, // Ana kaynak
            
            // Yeni eklenen güvenilir kaynak
            "https://cryptoicons-api.vercel.app/api/icon/\(coinSymbol)",
            
            // CoinGecko alternatifleri
            "https://assets.coingecko.com/coins/images/\(coinIdLower)/large/\(coinSymbol).png",
            "https://assets.coingecko.com/coins/images/\(coinIdLower)/thumb/\(coinSymbol).png",
            "https://assets.coingecko.com/coins/images/\(coinIdLower)/small/\(coinSymbol).png",
            
            // CoinMarketCap alternatifleri
            "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coinIdLower).png",
            "https://s2.coinmarketcap.com/static/img/coins/128x128/\(coinIdLower).png",
            "https://s2.coinmarketcap.com/static/img/coins/200x200/\(coinIdLower).png",
            
            // CoinCap alternatifleri
            "https://assets.coincap.io/assets/icons/\(coinSymbol)@2x.png",
            "https://static.coincap.io/assets/icons/\(coinSymbol)@2x.png",
            
            // GitHub açık kaynak repo alternatifleri
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(coinSymbol).png",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/32/color/\(coinSymbol).png",
            "https://raw.githubusercontent.com/coinicon/coinicon/master/public/coins/128/\(coinSymbol).png",
            
            // Diğer API ve CDN alternatifler
            "https://cryptoicons.org/api/icon/\(coinSymbol)/200",
            "https://cryptologos.cc/logos/\(coinIdLower)-\(coinSymbol)-logo.png",
            "https://lcw.nyc3.cdn.digitaloceanspaces.com/production/currencies/64/\(coinSymbol).png",
            "https://coinicons-api.vercel.app/api/icon/\(coinSymbol)",
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@master/128/color/\(coinSymbol).png",
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@master/32/color/\(coinSymbol).png",
            
            // ID tabanlı alternatifler
            "https://static.coincap.io/assets/icons/\(coinIdLower)@2x.png",
            "https://static.coinstats.app/coins/\(coinIdLower)@2x.png",
            "https://api.coinpaprika.com/coin/\(coinIdLower)/logo.png",
            "https://static.coinpaprika.com/coin/\(coinIdLower)/logo.png",
            
            // CryptoCompare
            "https://www.cryptocompare.com/media/\(coinIdLower)/\(coinSymbol).png",
            "https://www.cryptocompare.com/media/\(coinSymbol)/\(coinSymbol).png",
            
            // Yeni eklenen modern API kaynakları
            "https://cdn.coinranking.com/assets/coins/\(coinSymbol).svg",
            "https://cdn.coinranking.com/assets/coins/\(coinSymbol).png"
        ]
        
        // URL'leri sırayla dene
        for urlString in possibleURLs {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                // Request oluştur
                var request = URLRequest(url: url)
                request.timeoutInterval = 5 // 5 saniye timeout
                request.setValue("image/*", forHTTPHeaderField: "Accept")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // HTTP yanıt kontrolü
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    continue // Bu URL başarısız, bir sonrakini dene
                }
                
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