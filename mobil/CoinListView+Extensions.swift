import SwiftUI

// MARK: - CoinListView Uzantısı
extension CoinListView {
    private var loadingIndicator: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                .padding(.vertical, 10)
        }
    }
}

// MARK: - CoinCellView Bileşeni
struct CoinCellView2: View {
    let coin: Coin
    let displayRank: Int
    
    // Logoyu göstermek için state değişkeni
    @State private var logoImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 5) {
            // Sıralama
            Text("\(displayRank)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .center)
            
            // Logo ve isim
            HStack(spacing: 8) {
                // Logo görünümü - Önbellekten veya varsayılan
                if let logoImage = logoImage {
                    // Önbellekten logo göster
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else {
                    // Varsayılan renk göster
                    Circle()
                        .fill(coinColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(coin.symbol.prefix(1).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
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
        .background(Color.black.opacity(0.001)) // Daha iyi tap alanı için
        .onAppear(perform: loadLogo)
        .onReceive(NotificationCenter.default.publisher(for: LogoPreloader.logoPreloadedNotification)) { notification in
            // Logo yüklendiğinde güncellemek için
            if let coinId = notification.object as? String, coinId == coin.id {
                loadLogo()
            }
        }
    }
    
    // Logo yükleme fonksiyonu
    private func loadLogo() {
        // Önbellek anahtarı
        let cacheKey = "\(coin.id)_\(coin.symbol)_logo"
        
        // Önbellekten logoyu al
        if let cachedImage = ImageCache.shared.getImage(forKey: cacheKey) {
            self.logoImage = cachedImage
            return
        }
        
        // Alternatif anahtarları dene
        let altCacheKey = "\(coin.id)_logo"
        if let altCachedImage = ImageCache.shared.getImage(forKey: altCacheKey) {
            self.logoImage = altCachedImage
            return
        }
    }
    
    // Coin sembolüne göre renk oluştur
    private var coinColor: Color {
        let symbol = coin.symbol.lowercased()
        
        // Belirli kripto paralar için özel renkler
        if symbol == "btc" {
            return Color(red: 0.9, green: 0.6, blue: 0.0) // Bitcoin Gold
        } else if symbol == "eth" {
            return Color(red: 0.4, green: 0.4, blue: 0.8) // Ethereum Blue
        } else if symbol == "usdt" || symbol == "usdc" {
            return Color(red: 0.0, green: 0.7, blue: 0.4) // Stablecoin Green
        } else if symbol == "bnb" {
            return Color(red: 0.9, green: 0.8, blue: 0.2) // Binance Yellow
        } else if symbol == "xrp" {
            return Color(red: 0.0, green: 0.5, blue: 0.8) // Ripple Blue
        } else if symbol == "sol" {
            return Color(red: 0.4, green: 0.2, blue: 0.8) // Solana Purple
        }
        
        // Diğer tüm coinler için varsayılan renk
        return Color(red: 0.6, green: 0.6, blue: 0.6)
    }
} 