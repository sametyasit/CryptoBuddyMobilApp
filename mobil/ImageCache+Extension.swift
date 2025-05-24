import Foundation
import SwiftUI

// Bu uzantı, eski kodu çalışır durumda tutmak için eklendi
extension ImageCache {
    /// Yeni preloadCoinLogos metodu, global imageCacheHelper'a yönlendirir
    func preloadCoinLogos(for coins: [Coin]) {
        // Çağrıyı global helper'a yönlendir
        imageCacheHelper.preloadCoinLogos(for: coins)
    }
} 