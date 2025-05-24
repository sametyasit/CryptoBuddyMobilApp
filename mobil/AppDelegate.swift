//
//  AppDelegate.swift
//  mobil
//
//  Created by Samet on 03/04/2025.
//

import UIKit
import SwiftUI
import Foundation

// LogoPreloader ve ImageCache sınıflarını projenin diğer bölümlerinde tanımlandıkları şekilde kullanmak için

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Uygulama başlangıç konfigürasyonu
        return true
    }
    
    // MARK: - Önbellek İşlemleri
    
    /// Öncelikli kripto logolarını önbelleğe al
    private func preloadCryptoLogos() {
        print("📱 AppDelegate: Logo önbelleğe alma işlemi başlatılıyor...")
        
        // Background thread'de çalışacak API ve cache ön-yükleme
        DispatchQueue.global(qos: .userInitiated).async {
            // Popüler coinleri al ve önbelleğe al
            self.fetchAndPreloadPopularCoins()
        }
    }
    
    /// Popüler coinleri yükle ve önbelleğe al
    private func fetchAndPreloadPopularCoins() {
        Task {
            do {
                // İlk 20 coini yükle
                let response = try await APIService.shared.fetchCoins(page: 1, perPage: 20)
                
                // Logolar için önbelleğe alma - yüksek öncelikli
                if !response.coins.isEmpty {
                    print("📱 AppDelegate: \(response.coins.count) coinin logoları önbelleğe alınıyor...")
                    
                    // Basit bir önbelleğe alma mekanizması kullan
                    Task.detached(priority: .userInitiated) {
                        let topCoins = Array(response.coins.prefix(20))
                        
                        for coin in topCoins {
                            // Coinin logosu varsa indir
                            if let logoUrl = URL(string: coin.image) {
                                do {
                                    let (data, _) = try await URLSession.shared.data(from: logoUrl)
                                    if let _ = UIImage(data: data) {
                                        print("✅ \(coin.name) logosu başarıyla indirildi")
                                    }
                                } catch {
                                    print("⚠️ \(coin.name) logosu indirilemedi: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        print("✅ \(topCoins.count) coinin logoları indirilmeye çalışıldı")
                    }
                }
            } catch {
                print("❌ AppDelegate: Coin logoları önbelleğe alınamadı: \(error.localizedDescription)")
            }
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

