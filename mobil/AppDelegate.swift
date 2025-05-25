//
//  AppDelegate.swift
//  mobil
//
//  Created by Samet on 03/04/2025.
//

import UIKit
import SwiftUI
import Foundation
// CryptoIconsHelper için gerekli importlar
import UIKit

// LogoPreloader ve ImageCache sınıflarını projenin diğer bölümlerinde tanımlandıkları şekilde kullanmak için

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Uygulama başlangıcında logo yükleme işlemini başlat
        preloadCryptoLogos()
        return true
    }
    
    // MARK: - Önbellek İşlemleri
    
    /// Öncelikli kripto logolarını önbelleğe al
    private func preloadCryptoLogos() {
        print("📱 AppDelegate: Logo önbelleğe alma işlemi başlatılıyor...")
        
        // Düşük öncelikli bir kuyrukta çalıştır, kullanıcı arayüzünü bloklamasın
        DispatchQueue.global(qos: .utility).async {
            // Popüler coinlerin sembolleri
            let popularCoins = [
                "btc", "eth", "usdt", "bnb", "xrp", "sol", "usdc", "ada", "doge", "trx"
            ]
            
            // Güvenilir logo URL'leri
            let logoURLs: [String: String] = [
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
            
            // Her popüler coin için logo yükleme işlemini başlat
            for symbol in popularCoins {
                let lowerSymbol = symbol.lowercased()
                let cacheKey = "\(lowerSymbol)_direct_logo"
                
                // Logo URL'si oluştur
                if let urlString = logoURLs[lowerSymbol], let url = URL(string: urlString) {
                    // Görseli indir
                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                        if let data = data, let image = UIImage(data: data) {
                            // Önbelleğe al - DirectCoinLogoView aynı anahtarı kullanacak
                            self.saveImageToCache(image, forKey: cacheKey)
                            print("✅ \(symbol.uppercased()) logosu önbelleğe alındı")
                        }
                    }
                    task.resume()
                }
            }
            
            print("✅ Popüler coin logoları arka planda yükleniyor...")
        }
    }
    
    // ImageCache olmadan doğrudan önbelleğe alma
    private func saveImageToCache(_ image: UIImage, forKey key: String) {
        // UserDefaults'a kaydet
        if let data = image.pngData() {
            UserDefaults.standard.set(data, forKey: "image_cache_\(key)")
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

