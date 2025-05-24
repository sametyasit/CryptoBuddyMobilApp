import SwiftUI

/// Basit bir placeholder bileşeni - CoinLogoView yerine kullanılabilir
struct CirclePlaceholder: View {
    let symbol: String
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(generateColorForSymbol(symbol))
            .frame(width: size, height: size)
            .overlay(
                Text(symbol.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
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
            red: max(0.5, min(0.9, red)),     // En az 0.5, en çok 0.9
            green: max(0.5, min(0.9, green)), // En az 0.5, en çok 0.9
            blue: max(0.5, min(0.9, blue))    // En az 0.5, en çok 0.9
        )
    }
} 