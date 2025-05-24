import Foundation
import UIKit
import SwiftUI

/// Logo ön yükleme işlemleri için yardımcı sınıf
enum LogoPreloader {
    /// Coin logolarını toplu olarak yükle
    /// - Parameter coins: Yüklenecek coinler
    static func preloadLogos(for coins: [Coin]) {
        // İlk 20 coinin logolarını yükle
        Task.detached(priority: .background) {
            for coin in coins.prefix(20) {
                if let url = URL(string: coin.image) {
                    let _ = URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
                }
            }
        }
    }
} 