import SwiftUI
import UIKit // UIImage için gerekli

// MARK: - CoinCellView Bileşeni
struct CoinCellViewCustom: View {
    let coin: Coin
    let displayRank: Int
    
    // Logoyu göstermek için state değişkeni
    @State private var logoImage: UIImage? = nil
    @State private var isLoadingLogo: Bool = false
    
    // Önbellek için CoinCellView'deki önbelleği kullan
    private var imageCache: NSCache<NSString, UIImage> {
        return CoinCellView.imageCache
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
                // Logo görünümü - Önbellekten veya varsayılan
                if let logoImage = logoImage {
                    // Önbellekten logo göster
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else {
                    // Yükleme durumu veya varsayılan renk göster
                    ZStack {
                        Circle()
                            .fill(coinColor)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text(coin.symbol.prefix(1).uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        if isLoadingLogo {
                            Circle()
                                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                                .frame(width: 30, height: 30)
                        }
                    }
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
    }
    
    // Logo yükleme fonksiyonu
    private func loadLogo() {
        // Önbellek anahtarı
        let cacheKey = "\(coin.id)_\(coin.symbol)_logo" as NSString
        
        // Önbellekten logoyu al
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            self.logoImage = cachedImage
            return
        }
        
        // URL'den logoya erişmeyi dene
        guard let imageUrl = URL(string: coin.image) else { return }
        
        isLoadingLogo = true
        
        // Arka planda yükleme yap
        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            // Yükleme durumunu kapat
            DispatchQueue.main.async {
                self.isLoadingLogo = false
            }
            
            // Hata kontrolü
            guard error == nil else {
                print("⚠️ Logo yüklenirken hata: \(error!.localizedDescription)")
                return
            }
            
            // Data kontrolü
            guard let data = data else { return }
            
            // UIImage oluştur
            guard let image = UIImage(data: data) else { return }
            
            // Önbelleğe ekle
            self.imageCache.setObject(image, forKey: cacheKey)
            
            // UI'ı güncelle
            DispatchQueue.main.async {
                self.logoImage = image
            }
        }.resume()
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