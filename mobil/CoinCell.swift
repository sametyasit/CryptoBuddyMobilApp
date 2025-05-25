import SwiftUI
import UIKit

struct CoinCell: View {
    let coin: Coin
    let displayRank: Int
    
    init(coin: Coin, displayRank: Int? = nil) {
        self.coin = coin
        self.displayRank = displayRank ?? coin.rank
    }
    
    var body: some View {
        HStack(spacing: 5) {
            // Sıralama
            Text("\(displayRank)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .center)
            
            // Logo ve isim
            HStack(spacing: 8) {
                // Yeni CoinIconView ile logo gösterimi
                DirectCoinLogoView(
                    symbol: coin.symbol,
                    size: 30
                )
                .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(coin.symbol)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            // Fiyat
            Text(coin.formattedPrice)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 100, alignment: .trailing)
            
            // 24 saatlik değişim
            HStack(spacing: 3) {
                Image(systemName: coin.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundColor(coin.changeColor)
                
                Text(coin.formattedChange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(coin.changeColor)
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.001)) // Daha iyi tap alanı için
    }
}

// Doğrudan logo gösterimi için daha basit ve güvenilir bir bileşen
struct DirectCoinLogoView: View {
    let symbol: String
    let size: CGFloat
    
    @State private var logoImage: UIImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let logoImage = logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
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
            
            // Yükleme göstergesi
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
            }
        }
        .onAppear {
            loadLogo()
        }
    }
    
    private func loadLogo() {
        isLoading = true
        
        // Sembol ve büyük/küçük harf uyumluluğu için
        let lowerSymbol = symbol.lowercased()
        
        // Önbellek anahtarı
        let cacheKey = "\(lowerSymbol)_direct_logo"
        
        // Önbellekten kontrol et
        if let cachedImage = getImageFromCache(forKey: cacheKey) {
            self.logoImage = cachedImage
            self.isLoading = false
            return
        }
        
        // Popüler coinler için doğrudan URL'ler
        let popularCoins: [String: String] = [
            "btc": "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
            "eth": "https://cryptologos.cc/logos/ethereum-eth-logo.png",
            "usdt": "https://cryptologos.cc/logos/tether-usdt-logo.png",
            "bnb": "https://cryptologos.cc/logos/bnb-bnb-logo.png",
            "xrp": "https://cryptologos.cc/logos/xrp-xrp-logo.png",
            "sol": "https://cryptologos.cc/logos/solana-sol-logo.png",
            "usdc": "https://cryptologos.cc/logos/usd-coin-usdc-logo.png",
            "ada": "https://cryptologos.cc/logos/cardano-ada-logo.png",
            "doge": "https://cryptologos.cc/logos/dogecoin-doge-logo.png",
            "trx": "https://cryptologos.cc/logos/tron-trx-logo.png"
        ]
        
        // Alternatif URL listesi
        var alternativeURLs = [String]()
        
        // Önce popüler coinleri kontrol et
        if let popularURL = popularCoins[lowerSymbol] {
            alternativeURLs.append(popularURL)
        }
        
        // Diğer tüm API'ler
        alternativeURLs.append(contentsOf: [
            "https://cryptologos.cc/logos/\(lowerSymbol)-\(lowerSymbol)-logo.png", // En güvenilir
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/32/color/\(lowerSymbol).png",
            "https://coinicons-api.vercel.app/api/icon/\(lowerSymbol)",
            "https://s2.coinmarketcap.com/static/img/coins/64x64/\(lowerSymbol).png",
            "https://cryptoicon-api.vercel.app/api/icon/\(lowerSymbol)"
        ])
        
        // URL'leri sırayla dene
        tryNextURL(alternativeURLs, index: 0)
    }
    
    private func tryNextURL(_ urls: [String], index: Int) {
        guard index < urls.count else {
            // Tüm URL'ler denendi başarısız oldu
            isLoading = false
            return
        }
        
        let urlString = urls[index]
        
        guard let url = URL(string: urlString) else {
            // Geçersiz URL, sonraki dene
            tryNextURL(urls, index: index + 1)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3 // Daha hızlı zaman aşımı
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Hata kontrolü
            if error != nil {
                DispatchQueue.main.async {
                    tryNextURL(urls, index: index + 1)
                }
                return
            }
            
            // HTTP yanıt kontrolü
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    tryNextURL(urls, index: index + 1)
                }
                return
            }
            
            // Görsel verisi kontrolü
            guard let data = data, !data.isEmpty, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    tryNextURL(urls, index: index + 1)
                }
                return
            }
            
            // Başarılı
            DispatchQueue.main.async {
                self.logoImage = image
                self.isLoading = false
                
                // Önbelleğe kaydet
                self.saveImageToCache(image, forKey: "\(symbol.lowercased())_direct_logo")
            }
        }.resume()
    }
    
    // UserDefaults ile önbellekten görsel alma
    private func getImageFromCache(forKey key: String) -> UIImage? {
        if let data = UserDefaults.standard.data(forKey: "image_cache_\(key)") {
            return UIImage(data: data)
        }
        return nil
    }
    
    // UserDefaults ile önbelleğe görsel kaydetme
    private func saveImageToCache(_ image: UIImage, forKey key: String) {
        if let data = image.pngData() {
            UserDefaults.standard.set(data, forKey: "image_cache_\(key)")
        }
    }
    
    // Coin sembolünden tutarlı bir renk üret
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
            red: max(0.5, min(0.9, red)),
            green: max(0.5, min(0.9, green)),
            blue: max(0.5, min(0.9, blue))
        )
    }
} 