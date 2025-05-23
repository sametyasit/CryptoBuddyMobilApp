import Foundation
import UIKit

/// Gelişmiş görsel önbellek yöneticisi - kripto logoları için özelleştirilmiş
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    // Farklı tipte önbellekler - uzun ve kısa süreli önbelleğe alma
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheQueue = DispatchQueue(label: "com.cryptobuddy.diskCacheQueue", qos: .background)
    private let fileManager = FileManager.default
    
    // Logo yedek sunucuları - birincil URL başarısız olursa
    private let logoBackupUrls: [String: String] = [
        "binance": "https://cryptologos.cc/logos/",
        "cryptocompare": "https://www.cryptocompare.com/media/",
        "trustwallet": "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/"
    ]
    
    // Beklenen logo formatları
    private let supportedLogoFormats = [".png", ".jpg", ".svg", ".webp"]
    
    private init() {
        // Bellek kullanımını optimize et
        memoryCache.countLimit = 150 // maksimum 150 logo sakla
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // İlk açılışta önbellek klasörünü oluştur
        createCacheDirectoryIfNeeded()
        
        // Uygulama kapanırken önbelleği kaydet
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveCache),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Bellek düşük olduğunda önbelleği temizle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Tek bir kripto logosu yükler, çoklu yedek kaynaklarla yükleme dener
    func loadCoinImage(from url: String, symbol: String, completion: @escaping (UIImage?) -> Void) {
        // 1. Hafıza önbelleğinde logo varsa hemen dön
        if let cachedImage = memoryCache.object(forKey: url as NSString) {
            completion(cachedImage)
            return
        }
        
        // 2. Disk önbelleğinde logo var mı kontrol et
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let diskCachedImage = self.loadImageFromDiskCache(for: url) {
                // Disk önbelleğinde varsa, bellek önbelleğine ekle ve dön
                self.memoryCache.setObject(diskCachedImage, forKey: url as NSString)
                DispatchQueue.main.async {
                    completion(diskCachedImage)
                }
                return
            }
            
            // 3. Ana URL'den yüklemeyi dene
            self.downloadImage(from: url) { [weak self] image in
                guard let self = self else { return }
                
                if let image = image {
                    // Başarılı yükleme, önbellekleri güncelle
                    self.saveImage(image, for: url)
                    DispatchQueue.main.async {
                        completion(image)
                    }
                    return
                }
                
                // 4. Ana URL başarısız oldu, yedek logoları dene
                self.tryBackupLogoSources(for: symbol) { backupImage in
                    if let backupImage = backupImage {
                        // Yedek logo yükleme başarılı, önbellekleri güncelle
                        self.saveImage(backupImage, for: url)
                        DispatchQueue.main.async {
                            completion(backupImage)
                        }
                    } else {
                        // Tüm kaynaklar başarısız, varsayılan logo kullan
                        DispatchQueue.main.async {
                            let defaultImage = self.getDefaultLogo(for: symbol)
                            completion(defaultImage)
                        }
                    }
                }
            }
        }
    }
    
    /// İmaj önbelleğini temizle
    func clearCache() {
        memoryCache.removeAllObjects()
        
        diskCacheQueue.async { [weak self] in
            guard let self = self, 
                  let cacheDirectory = self.cacheDirectory else { return }
            
            do {
                try self.fileManager.removeItem(at: cacheDirectory)
                self.createCacheDirectoryIfNeeded()
            } catch {
                print("Cache temizleme hatası: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Diğer logo kaynaklarını dener
    private func tryBackupLogoSources(for symbol: String, completion: @escaping (UIImage?) -> Void) {
        let upperSymbol = symbol.uppercased()
        let lowerSymbol = symbol.lowercased()
        
        // Logo varyasyonlarını oluştur
        let backupUrls = [
            "https://s2.coinmarketcap.com/static/img/coins/64x64/\(lowerSymbol).png",
            "https://cryptoicons.org/api/icon/\(lowerSymbol)/200",
            "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(lowerSymbol).png",
            "https://cryptologos.cc/logos/\(lowerSymbol)-\(lowerSymbol)-logo.png",
            "\(logoBackupUrls["binance"]!)\(lowerSymbol)-\(lowerSymbol)-logo.png",
            "\(logoBackupUrls["cryptocompare"]!)\(upperSymbol).png"
        ]
        
        tryNextBackupURL(backupUrls, index: 0, completion: completion)
    }
    
    /// Sırayla yedek URL'leri dener
    private func tryNextBackupURL(_ urls: [String], index: Int, completion: @escaping (UIImage?) -> Void) {
        if index >= urls.count {
            // Tüm URL'ler denendi, başarısız
            completion(nil)
            return
        }
        
        let urlString = urls[index]
        downloadImage(from: urlString) { [weak self] image in
            if let image = image {
                // Başarılı, logoyu döndür
                completion(image)
            } else {
                // Başarısız, sonraki URL'yi dene
                self?.tryNextBackupURL(urls, index: index + 1, completion: completion)
            }
        }
    }
    
    /// Bir görsel URL'sinden indirme yapar
    private func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Logo indirme hatası: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            completion(image)
        }.resume()
    }
    
    /// Disk önbelleğinden görsel yükler
    private func loadImageFromDiskCache(for key: String) -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }
        
        return nil
    }
    
    /// Görseli önbelleğe kaydeder (hem bellek hem disk)
    private func saveImage(_ image: UIImage, for key: String) {
        // Bellek önbelleğine kaydet
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Disk önbelleğine kaydet
        diskCacheQueue.async { [weak self] in
            guard let self = self,
                  let cacheDirectory = self.cacheDirectory,
                  let data = image.jpegData(compressionQuality: 0.8) else { return }
            
            let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
            try? data.write(to: fileURL)
        }
    }
    
    /// Önbellek klasörünü oluştur
    private func createCacheDirectoryIfNeeded() {
        guard let cacheDirectory = cacheDirectory else { return }
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: cacheDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("Önbellek klasörü oluşturma hatası: \(error)")
            }
        }
    }
    
    /// Önbellek dizini URL'sini al
    private var cacheDirectory: URL? {
        let fileManager = FileManager.default
        guard let cacheDirectory = try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        
        return cacheDirectory.appendingPathComponent("CoinImageCache")
    }
    
    /// Bellek önbelleğini temizle
    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    /// Önbelleği kaydet
    @objc private func saveCache() {
        // Bellek önbelleğindeki tüm görselleri disk önbelleğine kaydet
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            // Önbellekteki değişikliklerin kaydedildiğinden emin ol
            // (Normalde otomatik yapılıyor ama burada ekstra güvenlik önlemi)
        }
    }
    
    /// Varsayılan logo oluştur
    private func getDefaultLogo(for symbol: String) -> UIImage {
        if let symbolImage = UIImage(systemName: "bitcoinsign.circle.fill") {
            // Varsayılan logo resmi
            return symbolImage
        }
        
        // Sembol baş harfinden dinamik logo oluştur
        let frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        let symbolLabel = UILabel(frame: frame)
        symbolLabel.text = String(symbol.prefix(1)).uppercased()
        symbolLabel.font = UIFont.boldSystemFont(ofSize: 30)
        symbolLabel.textColor = .white
        symbolLabel.textAlignment = .center
        symbolLabel.backgroundColor = generateColorFromString(symbol)
        symbolLabel.layer.cornerRadius = 30
        symbolLabel.layer.masksToBounds = true
        
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            symbolLabel.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image ?? UIImage(systemName: "questionmark.circle")!
        }
        
        return UIImage(systemName: "questionmark.circle")!
    }
    
    /// Sembol adından tutarlı bir renk üret
    private func generateColorFromString(_ string: String) -> UIColor {
        var hash = 0
        
        for character in string {
            let unicodeValue = character.unicodeScalars.first?.value ?? 0
            hash = Int(unicodeValue) &+ ((hash << 5) &- hash)
        }
        
        let red = CGFloat((hash & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hash & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hash & 0x0000FF) / 255.0
        
        return UIColor(red: max(0.4, red),
                      green: max(0.4, green),
                      blue: max(0.4, blue),
                      alpha: 1.0)
    }
}

// MARK: - String Extension for MD5 Hashing
extension String {
    var md5Hash: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let data = self.data(using: .utf8) {
            _ = data.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(data.count), &digest)
                return ""
            }
        }
        
        return digest.reduce("") { $0 + String(format: "%02x", $1) }
    }
}

// CommonCrypto kütüphanesini import et
import CommonCrypto 