import SwiftUI
import UIKit
import Foundation

struct CoinLogoView: View {
    let coinId: String
    let urlString: String
    let symbol: String
    let size: CGFloat
    
    @State private var logoImage: UIImage? = nil
    @State private var isLoading = true
    @State private var retryCount = 0
    @State private var currentAttempt = 0
    @State private var alternativeURLs: [String] = []
    @State private var errorOccurred = false
    
    init(coinId: String, urlString: String, symbol: String = "", size: CGFloat = 40) {
        self.coinId = coinId
        self.urlString = urlString
        self.symbol = symbol.isEmpty ? coinId : symbol
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if let logoImage = logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .transition(.opacity)
            } else {
                // Arkaplan rengi için tutarlı bir renk oluştur
                Circle()
                    .fill(generateColorForSymbol(symbol))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(symbol.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            // Yükleme göstergesi - sadece ilk yüklemede
            if isLoading && retryCount == 0 && !errorOccurred {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
            }
        }
        .onAppear {
            prepareAlternativeURLs()
            loadCoinLogo()
        }
        .id("\(coinId)_\(symbol)_logo") // Zorla yeniden oluşturma için view ID'si
    }
    
    // Tüm olası logo URL'lerini hazırla - Daha fazla alternatif eklendi
    private func prepareAlternativeURLs() {
        let coinSymbol = symbol.lowercased()
        let coinIdLower = coinId.lowercased()
        
        alternativeURLs = [
            urlString, // Ana kaynak
            
            // CoinGecko alternatifleri
            "https://assets.coingecko.com/coins/images/\(coinIdLower)/large/\(coinSymbol).png",
            "https://assets.coingecko.com/coins/images/\(coinIdLower)/thumb/\(coinSymbol).png",
            "https://assets.coingecko.com/coins/images/\(coinIdLower)/small/\(coinSymbol).png",
            
            // CoinMarketCap alternatifleri
            "https://s2.coinmarketcap.com/static/img/coins/64x64/\(coinIdLower).png",
            "https://s2.coinmarketcap.com/static/img/coins/128x128/\(coinIdLower).png",
            
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
            "https://cryptoicon-api.vercel.app/api/icon/\(coinSymbol)",
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@master/128/color/\(coinSymbol).png",
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@master/32/color/\(coinSymbol).png",
            
            // ID tabanlı alternatifler
            "https://static.coincap.io/assets/icons/\(coinIdLower)@2x.png",
            "https://static.coinstats.app/coins/\(coinIdLower)@2x.png",
            "https://api.coinpaprika.com/coin/\(coinIdLower)/logo.png"
        ]
        
        // Bitcoin için özel alternatifler
        if coinSymbol == "btc" || coinIdLower == "bitcoin" {
            alternativeURLs.append(contentsOf: [
                "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
                "https://assets.coingecko.com/coins/images/1/small/bitcoin.png",
                "https://s2.coinmarketcap.com/static/img/coins/64x64/1.png"
            ])
        }
        
        // Ethereum için özel alternatifler
        if coinSymbol == "eth" || coinIdLower == "ethereum" {
            alternativeURLs.append(contentsOf: [
                "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
                "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
                "https://s2.coinmarketcap.com/static/img/coins/64x64/1027.png"
            ])
        }
        
        // Tekrarlanan URL'leri kaldır
        alternativeURLs = Array(Set(alternativeURLs))
    }
    
    // Logoyu yükle - önbellekten veya çeşitli kaynaklardan
    private func loadCoinLogo() {
        isLoading = true
        
        // Önbellek anahtarı
        let cacheKey = "\(coinId)_\(symbol)_logo"
        
        // Önbellekten kontrol et
        if let cachedImage = ImageCache.shared.getImage(forKey: cacheKey) {
            withAnimation(.easeIn(duration: 0.2)) {
                logoImage = cachedImage
                isLoading = false
            }
            return
        }
        
        // Alternatif kaynaklardan sırayla dene
        currentAttempt = 0
        errorOccurred = false
        tryNextLogoSource()
    }
    
    // Alternatif URL'lerden logo yüklemeyi dene - Geliştirilmiş hata yönetimi ile
    private func tryNextLogoSource() {
        guard currentAttempt < alternativeURLs.count else {
            // Tüm kaynaklar denendi ve bulunamadı
            DispatchQueue.main.async {
                isLoading = false
                errorOccurred = true
                
                // Retry mantığı - maksimum 3 deneme
                if retryCount < 2 {
                    // Bir süre bekleyip tekrar dene
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        retryCount += 1
                        currentAttempt = 0
                        errorOccurred = false
                        tryNextLogoSource()
                    }
                }
            }
            return
        }
        
        let currentURLString = alternativeURLs[currentAttempt]
        currentAttempt += 1
        
        guard !currentURLString.isEmpty, let url = URL(string: currentURLString) else {
            // Geçersiz URL, bir sonraki kaynağı dene
            tryNextLogoSource()
            return
        }
        
        // Zaman aşımı ekleyerek ImageCache kullanarak yükle
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    // Başarılı yüklemeyi önbelleğe kaydet
                    ImageCache.shared.setImage(image, forKey: "\(coinId)_\(symbol)_logo")
                    
                    withAnimation(.easeIn(duration: 0.3)) {
                        logoImage = image
                        isLoading = false
                        errorOccurred = false
                    }
                }
            } else {
                // Bu kaynak başarısız oldu, sonrakini dene
                tryNextLogoSource()
            }
        }
        
        // 5 saniye zaman aşımı ekle
        let timeoutTask = DispatchWorkItem {
            task.cancel()
            // Zaman aşımı, sonraki kaynağı dene
            tryNextLogoSource()
        }
        
        // Zaman aşımını başlat
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutTask)
        
        // İndirme görevini başlat
        task.resume()
    }
    
    // Coin sembolünden tutarlı bir renk üret - Daha canlı renkler için iyileştirildi
    private func generateColorForSymbol(_ symbol: String) -> Color {
        var hash = 0
        
        for char in symbol {
            let unicodeValue = Int(char.unicodeScalars.first?.value ?? 0)
            hash = ((hash << 5) &- hash) &+ unicodeValue
        }
        
        // Belirli kripto paralar için özel renkler
        if symbol.lowercased() == "btc" {
            return Color(red: 0.9, green: 0.6, blue: 0.0) // Bitcoin Gold
        } else if symbol.lowercased() == "eth" {
            return Color(red: 0.4, green: 0.4, blue: 0.8) // Ethereum Blue
        } else if symbol.lowercased() == "usdt" || symbol.lowercased() == "usdc" {
            return Color(red: 0.0, green: 0.7, blue: 0.4) // Stablecoin Green
        } else if symbol.lowercased() == "bnb" {
            return Color(red: 0.9, green: 0.8, blue: 0.2) // Binance Yellow
        } else if symbol.lowercased() == "xrp" {
            return Color(red: 0.0, green: 0.5, blue: 0.8) // Ripple Blue
        } else if symbol.lowercased() == "sol" {
            return Color(red: 0.4, green: 0.2, blue: 0.8) // Solana Purple
        }
        
        // Diğer tüm coinler için - Daha canlı renkler
        let red = CGFloat(abs(hash) % 255) / 255.0
        let green = CGFloat(abs(hash * 33) % 255) / 255.0
        let blue = CGFloat(abs(hash * 77) % 255) / 255.0
        
        return Color(
            red: max(0.5, min(0.9, red)),     // En az 0.5, en çok 0.9
            green: max(0.5, min(0.9, green)), // En az 0.5, en çok 0.9
            blue: max(0.5, min(0.9, blue))    // En az 0.5, en çok 0.9
        )
    }
} 