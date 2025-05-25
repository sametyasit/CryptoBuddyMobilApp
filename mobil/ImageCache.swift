import Foundation
import UIKit

/// Hem bellek hem de disk önbellekleme yapan gelişmiş bir görsel önbellekleme sistemi
class ImageCache {
    // Singleton örnek
    static let shared = ImageCache()
    
    // Bellek önbelleği
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Disk önbelleği için dosya yöneticisi
    private let fileManager = FileManager.default
    private let diskCacheFolder = "CoinLogoCache"
    
    // İstatistik değişkenleri
    private(set) var memoryHits = 0
    private(set) var diskHits = 0
    private(set) var networkHits = 0
    
    // Önbellekleme için zaman aşımı değerleri
    private let memoryCacheTimeoutHours: TimeInterval = 1 // 1 saat
    private let diskCacheTimeoutDays: TimeInterval = 7 // 1 hafta
    
    // Paralel indirme işlemleri için işlem kuyruğu
    private let downloadQueue = DispatchQueue(label: "com.cryptobuddy.imageDownloadQueue", attributes: .concurrent)
    
    // Yeni bir önbellek oluşturma
    private init() {
        // Bellek önbelleği yapılandırması
        memoryCache.countLimit = 300 // En fazla 300 görsel
        memoryCache.totalCostLimit = 50_000_000 // ~50MB bellek sınırı
        
        // Uygulama bellek uyarısı aldığında önbelleği temizleme
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Disk önbellek klasörünü oluştur
        createDiskCacheDirectory()
        
        // Eski önbellekleri temizle
        cleanExpiredDiskCache()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Bir görseli önbellekten alır veya indirir
    /// - Parameters:
    ///   - url: İndirilecek görsel URL'si
    ///   - completion: İndirme tamamlandığında çağrılacak closure
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let cacheKey = urlString as NSString
        
        // 1. Bellek önbelleğinden kontrol et
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            memoryHits += 1
            completion(cachedImage)
            return
        }
        
        // 2. Disk önbelleğinden kontrol et
        if let diskCachedImage = loadImageFromDiskCache(for: cacheKey as String) {
            diskHits += 1
            // Belleğe de ekle
            memoryCache.setObject(diskCachedImage, forKey: cacheKey)
            completion(diskCachedImage)
            return
        }
        
        // 3. Ağdan indir
        networkHits += 1
        downloadImage(from: url, cacheKey: cacheKey as String) { [weak self] image in
            if let image = image {
                self?.memoryCache.setObject(image, forKey: cacheKey)
                self?.saveImageToDiskCache(image, for: cacheKey as String)
            }
            completion(image)
        }
    }
    
    /// Toplu logo önbelleğe alma - Coin listesi görünümünden çağrılabilir
    /// - Parameter coins: Önbelleğe alınacak coinlerin listesi
    func preloadCoinLogos(for coins: [Coin]) {
        // İlk 50 coini önbelleğe al - kullanıcı deneyimini iyileştirmek için
        let topCoins = Array(coins.prefix(50))
        
        // Düşük öncelikli bir kuyrukta arkaplanda yükle
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            for coin in topCoins {
                let coinSymbol = coin.symbol.lowercased()
                let coinIdLower = coin.id.lowercased()
                
                // Logoları yüklerken daha kapsamlı URL listesi
                let possibleURLs = [
                    coin.image, // Ana URL
                    
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
                    
                    // CryptoCompare
                    "https://www.cryptocompare.com/media/\(coinIdLower)/\(coinSymbol).png",
                    
                    // Yeni modern API kaynakları
                    "https://coinicons-api.vercel.app/api/icon/\(coinSymbol)"
                ]
                
                // Her coin için bir kez başarılı olunca diğerine geç
                var logoLoaded = false
                
                for urlString in possibleURLs where !logoLoaded {
                    // Boş veya geçersiz URL'leri atla
                    guard !urlString.isEmpty, let url = URL(string: urlString) else { continue }
                    
                    // Önbellek anahtarı
                    let cacheKey = "\(coin.id)_\(coin.symbol)_logo"
                    
                    // Zaten önbellekte var mı kontrol et
                    if self.getImage(forKey: cacheKey) != nil {
                        logoLoaded = true
                        break
                    }
                    
                    // Değilse, indir ve önbelleğe al
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 5
                    request.setValue("image/*", forHTTPHeaderField: "Accept")
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
                        // HTTP yanıt kontrolü
                        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                            semaphore.signal()
                            return
                        }
                        
                        if let data = data, let image = UIImage(data: data) {
                            // Başarılı yüklemeyi önbelleğe kaydet
                            self.setImage(image, forKey: cacheKey)
                            logoLoaded = true
                        }
                        semaphore.signal()
                    }
                    
                    task.resume()
                    
                    // En fazla 3 saniye bekle ve sonraki URL'ye geç
                    _ = semaphore.wait(timeout: .now() + 3)
                    
                    if logoLoaded {
                        break
                    }
                }
            }
            
            print("📱 Logo önbelleğe alma tamamlandı - \(topCoins.count) coin için")
        }
    }
    
    /// Bir görseli önbelleğe alır
    /// - Parameters:
    ///   - image: Önbelleğe eklenecek görsel
    ///   - key: Önbellek anahtarı
    func setImage(_ image: UIImage, forKey key: String) {
        let cacheKey = key as NSString
        memoryCache.setObject(image, forKey: cacheKey)
        saveImageToDiskCache(image, for: key)
    }
    
    /// Bir görseli önbellekten alır
    /// - Parameter key: Önbellek anahtarı
    /// - Returns: Önbellekteki görsel veya nil
    func getImage(forKey key: String) -> UIImage? {
        let cacheKey = key as NSString
        
        // Bellek önbelleğinden kontrol
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            memoryHits += 1
            return cachedImage
        }
        
        // Disk önbelleğinden kontrol
        if let diskCachedImage = loadImageFromDiskCache(for: key) {
            diskHits += 1
            // Belleğe de ekle
            memoryCache.setObject(diskCachedImage, forKey: cacheKey)
            return diskCachedImage
        }
        
        return nil
    }
    
    /// Tüm önbelleği temizler
    func clearCache() {
        clearMemoryCache()
        clearDiskCache()
        
        // İstatistikleri sıfırla
        memoryHits = 0
        diskHits = 0
        networkHits = 0
    }
    
    // MARK: - Private Methods
    
    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    private func clearDiskCache() {
        do {
            let cacheURL = try diskCacheDirectoryURL()
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Disk önbelleği temizlenirken hata: \(error)")
        }
    }
    
    private func createDiskCacheDirectory() {
        do {
            let cacheURL = try diskCacheDirectoryURL()
            try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        } catch {
            print("Disk önbellek klasörü oluşturulurken hata: \(error)")
        }
    }
    
    private func diskCacheDirectoryURL() throws -> URL {
        let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return cacheDir.appendingPathComponent(diskCacheFolder)
    }
    
    private func fileURL(for key: String) throws -> URL {
        // URL'lerdeki geçersiz karakterleri işle
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
                         .replacingOccurrences(of: ":", with: "_")
                         .replacingOccurrences(of: "?", with: "_")
                         .replacingOccurrences(of: "&", with: "_")
                         .replacingOccurrences(of: "=", with: "_")
                         .replacingOccurrences(of: "%", with: "_")
        
        let cacheURL = try diskCacheDirectoryURL()
        return cacheURL.appendingPathComponent(safeKey)
    }
    
    private func loadImageFromDiskCache(for key: String) -> UIImage? {
        do {
            let fileURL = try fileURL(for: key)
            
            // Dosya yoksa nil döndür
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return nil
            }
            
            // Disk önbelleğindeki görseli yükle
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            print("Disk önbelleğinden yükleme hatası: \(error)")
            return nil
        }
    }
    
    private func saveImageToDiskCache(_ image: UIImage, for key: String) {
        do {
            let fileURL = try fileURL(for: key)
            
            // Görseli PNG veya JPEG olarak kaydet
            if let pngData = image.pngData() {
                try pngData.write(to: fileURL)
            } else if let jpegData = image.jpegData(compressionQuality: 0.9) {
                try jpegData.write(to: fileURL)
            }
        } catch {
            print("Disk önbelleğine kaydetme hatası: \(error)")
        }
    }
    
    private func downloadImage(from url: URL, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        downloadQueue.async {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Görsel indirme hatası: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                
                completion(image)
            }
            
            task.resume()
        }
    }
    
    private func cleanExpiredDiskCache() {
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let cacheURL = try self.diskCacheDirectoryURL()
                let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]
                let cacheContents = try self.fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: resourceKeys)
                
                // Disk önbelleğindeki eski dosyaları temizle
                let expirationDate = Date().addingTimeInterval(-self.diskCacheTimeoutDays * 24 * 60 * 60)
                
                for fileURL in cacheContents {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    // Dosya eski mi kontrol et
                    if let modificationDate = resourceValues.contentModificationDate,
                       modificationDate < expirationDate {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                }
            } catch {
                print("Disk önbelleği temizlenirken hata: \(error)")
            }
        }
    }
}

// MARK: - Uzantılar

extension UIImageView {
    /// Bir görseli URL'den yükler ve önbellekte saklar
    /// - Parameters:
    ///   - urlString: Görsel URL'si
    ///   - placeholder: Yükleme sırasında gösterilecek görsel
    func loadImage(from urlString: String, placeholder: UIImage? = nil) {
        self.image = placeholder
        
        ImageCache.shared.loadImage(from: urlString) { [weak self] image in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
                    self.image = image ?? placeholder
                }
            }
        }
    }
}

extension Image {
    /// SwiftUI için bir görseli URL'den yüklemek ve önbellekte saklamak için uzantı
    static func cachedImage(for urlString: String) -> Image {
        if let cachedImage = ImageCache.shared.getImage(forKey: urlString) {
            return Image(uiImage: cachedImage)
        }
        return Image(systemName: "photo")
    }
} 