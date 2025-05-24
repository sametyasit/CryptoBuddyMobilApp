import SwiftUI
import UIKit

struct CoinCell: View {
    let coin: Coin
    let displayRank: Int
    @State private var logoImage: UIImage? = nil
    @State private var isImageLoading = true
    
    init(coin: Coin, displayRank: Int? = nil) {
        self.coin = coin
        self.displayRank = displayRank ?? coin.rank
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
                // Gelişmiş logo görünümü
                CoinLogoView(
                    coinId: coin.id,
                    urlString: coin.image,
                    symbol: coin.symbol,
                    size: 30
                )
                
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
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.001)) // Daha iyi tap alanı için
    }
} 