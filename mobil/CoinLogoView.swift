import SwiftUI
import UIKit

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
            
            // Yükleme göstergesi - yalnızca ilk yüklemede
            if isLoading && retryCount == 0 {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
            }
        }
        .onAppear {
            prepareAlternativeURLs()
            loadCoinLogo()
        }
    }
    
    // Tüm olası logo URL'lerini hazırla
    private func prepareAlternativeURLs() {
        let coinSymbol = symbol.lowercased()
        let coinIdLower = coinId.lowercased()
        
        alternativeURLs = [
            urlString, // Ana kaynak
            "https://assets.coingecko.com/coins/images/1/large/\(coinIdLower).png",
            "https://s2.coinmarketcap.com/static/img/coins/128x128/\(coinIdLower).png",
            "https://cryptoicons.org/api/icon/\(coinSymbol)/200",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(coinSymbol).png",
            "https://cryptologos.cc/logos/\(coinIdLower)-\(coinSymbol)-logo.png",
            "https://assets.coincap.io/assets/icons/\(coinSymbol)@2x.png",
            "https://lcw.nyc3.cdn.digitaloceanspaces.com/production/currencies/64/\(coinSymbol).png",
            "https://coinicons-api.vercel.app/api/icon/\(coinSymbol)",
            "https://unpkg.com/cryptocurrency-icons@1.0.0/128/color/\(coinSymbol).png"
        ]
    }
    
    // Logoyu yükle - önbellekten veya çeşitli kaynaklardan
    private func loadCoinLogo() {
        isLoading = true
        
        // Önbellek anahtarı
        let cacheKey = "\(coinId)_logo"
        
        // Önbellekten kontrol et
        if let cachedImage = ImageCache.shared.getImage(forKey: cacheKey) {
            logoImage = cachedImage
            isLoading = false
            return
        }
        
        // Alternatif kaynaklardan sırayla dene
        tryNextLogoSource()
    }
    
    // Alternatif URL'lerden logo yüklemeyi dene
    private func tryNextLogoSource() {
        guard currentAttempt < alternativeURLs.count else {
            // Tüm kaynaklar denendi ve bulunamadı
            DispatchQueue.main.async {
                isLoading = false
                
                // 3 kere denediyse artık vazgeç
                if retryCount >= 2 {
                    return
                }
                
                // 1 saniye sonra tekrar dene
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    retryCount += 1
                    currentAttempt = 0
                    tryNextLogoSource()
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
        
        // ImageCache kullanarak yükle
        ImageCache.shared.loadImage(from: currentURLString) { image in
            if let image = image {
                DispatchQueue.main.async {
                    logoImage = image
                    isLoading = false
                }
            } else {
                // Bu kaynak başarısız oldu, sonrakini dene
                tryNextLogoSource()
            }
        }
    }
    
    // Coin ID'den tutarlı bir renk üret
    private func generateColorForSymbol(_ symbol: String) -> Color {
        var hash = 0
        
        for char in symbol {
            let unicodeValue = Int(char.unicodeScalars.first?.value ?? 0)
            hash = ((hash << 5) &- hash) &+ unicodeValue
        }
        
        let red = CGFloat(abs(hash) % 255) / 255.0
        let green = CGFloat(abs(hash * 33) % 255) / 255.0
        let blue = CGFloat(abs(hash * 77) % 255) / 255.0
        
        return Color(
            red: max(0.4, red),
            green: max(0.4, green),
            blue: max(0.4, blue)
        )
    }
} 