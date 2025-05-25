import SwiftUI
import UIKit

// Doğrudan logo gösterimi için daha basit ve güvenilir bir bileşen
struct DirectCoinLogoView: View {
    let symbol: String
    let size: CGFloat
    let coinId: String?
    let imageUrl: String?
    
    @State private var logoImage: UIImage? = nil
    @State private var isLoading = true
    
    // Convenience initializer - sadece symbol ile
    init(symbol: String, size: CGFloat) {
        self.symbol = symbol
        self.size = size
        self.coinId = nil
        self.imageUrl = nil
    }
    
    // Full initializer - symbol ve coinId ile
    init(symbol: String, size: CGFloat, coinId: String?) {
        self.symbol = symbol
        self.size = size
        self.coinId = coinId
        self.imageUrl = nil
    }
    
    // Complete initializer - tüm parametreler ile
    init(symbol: String, size: CGFloat, coinId: String?, imageUrl: String?) {
        self.symbol = symbol
        self.size = size
        self.coinId = coinId
        self.imageUrl = imageUrl
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
        
        // Popüler coinler için doğrudan URL'ler - daha kapsamlı liste
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
            "trx": "https://cryptologos.cc/logos/tron-trx-logo.png",
            "avax": "https://cryptologos.cc/logos/avalanche-avax-logo.png",
            "dot": "https://cryptologos.cc/logos/polkadot-new-dot-logo.png",
            "matic": "https://cryptologos.cc/logos/polygon-matic-logo.png",
            "shib": "https://cryptologos.cc/logos/shiba-inu-shib-logo.png",
            "ltc": "https://cryptologos.cc/logos/litecoin-ltc-logo.png",
            "link": "https://cryptologos.cc/logos/chainlink-link-logo.png",
            "uni": "https://cryptologos.cc/logos/uniswap-uni-logo.png",
            "atom": "https://cryptologos.cc/logos/cosmos-atom-logo.png",
            "etc": "https://cryptologos.cc/logos/ethereum-classic-etc-logo.png",
            "xlm": "https://cryptologos.cc/logos/stellar-xlm-logo.png",
            "bch": "https://cryptologos.cc/logos/bitcoin-cash-bch-logo.png",
            "algo": "https://cryptologos.cc/logos/algorand-algo-logo.png",
            "vet": "https://cryptologos.cc/logos/vechain-vet-logo.png",
            "icp": "https://cryptologos.cc/logos/internet-computer-icp-logo.png",
            "fil": "https://cryptologos.cc/logos/filecoin-fil-logo.png",
            "hbar": "https://cryptologos.cc/logos/hedera-hbar-logo.png",
            "xmr": "https://cryptologos.cc/logos/monero-xmr-logo.png",
            "ton": "https://cryptologos.cc/logos/toncoin-ton-logo.png",
            "bgb": "https://cryptologos.cc/logos/bitget-token-bgb-logo.png",
            "pi": "https://cryptologos.cc/logos/pi-network-pi-logo.png"
        ]
        
        // Alternatif URL listesi
        var alternativeURLs = [String]()
        
        // Önce popüler coinleri kontrol et
        if let popularURL = popularCoins[lowerSymbol] {
            alternativeURLs.append(popularURL)
        }
        
        // Özel coin ID eşleştirmeleri
        let specialCoinIds: [String: String] = [
            "bitcoin": "btc",
            "ethereum": "eth",
            "tether": "usdt",
            "binancecoin": "bnb",
            "ripple": "xrp",
            "solana": "sol",
            "usd-coin": "usdc",
            "cardano": "ada",
            "dogecoin": "doge",
            "tron": "trx",
            "avalanche-2": "avax",
            "polkadot": "dot",
            "polygon": "matic",
            "shiba-inu": "shib",
            "litecoin": "ltc",
            "chainlink": "link",
            "uniswap": "uni",
            "cosmos": "atom",
            "ethereum-classic": "etc",
            "stellar": "xlm",
            "bitcoin-cash": "bch",
            "algorand": "algo",
            "vechain": "vet",
            "internet-computer": "icp",
            "filecoin": "fil",
            "hedera-hashgraph": "hbar",
            "monero": "xmr",
            "the-open-network": "ton",
            "bitget-token": "bgb"
        ]
        
        // Eğer coinId özel eşleştirmede varsa, o sembolü kullan
        if let coinId = coinId, let specialSymbol = specialCoinIds[coinId.lowercased()],
           let specialURL = popularCoins[specialSymbol] {
            alternativeURLs.insert(specialURL, at: 0) // En başa ekle
        }
        
        // API'den gelen image URL'sini de en başa ekle (en yüksek öncelik)
        if let imageUrl = imageUrl, !imageUrl.isEmpty, imageUrl.hasPrefix("http") {
            alternativeURLs.insert(imageUrl, at: 0)
        }
        
        // Diğer tüm API'ler - daha kapsamlı liste
        alternativeURLs.append(contentsOf: [
            "https://cryptologos.cc/logos/\(lowerSymbol)-\(lowerSymbol)-logo.png", // En güvenilir
            "https://assets.coingecko.com/coins/images/1/large/\(lowerSymbol).png",
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/32/color/\(lowerSymbol).png",
            "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/128/color/\(lowerSymbol).png",
            "https://coinicons-api.vercel.app/api/icon/\(lowerSymbol)",
            "https://s2.coinmarketcap.com/static/img/coins/64x64/\(lowerSymbol).png",
            "https://cryptoicon-api.vercel.app/api/icon/\(lowerSymbol)",
            "https://assets.coincap.io/assets/icons/\(lowerSymbol)@2x.png",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/32/color/\(lowerSymbol).png",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(lowerSymbol).png",
            "https://cryptoicons.org/api/icon/\(lowerSymbol)/200",
            "https://wallet-asset.matic.network/img/tokens/\(lowerSymbol).svg",
            "https://tokens.1inch.io/\(lowerSymbol).png"
        ])
        
        // Eğer coinId varsa, coinId ile de deneyelim
        if let coinId = coinId, !coinId.isEmpty {
            let lowerCoinId = coinId.lowercased()
            alternativeURLs.append(contentsOf: [
                "https://cryptologos.cc/logos/\(lowerCoinId)-\(lowerSymbol)-logo.png",
                "https://assets.coingecko.com/coins/images/1/large/\(lowerCoinId).png",
                "https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/32/color/\(lowerCoinId).png",
                "https://coinicons-api.vercel.app/api/icon/\(lowerCoinId)",
                "https://assets.coincap.io/assets/icons/\(lowerCoinId)@2x.png"
            ])
        }
        
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
        request.timeoutInterval = 5 // Biraz daha uzun zaman aşımı
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
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