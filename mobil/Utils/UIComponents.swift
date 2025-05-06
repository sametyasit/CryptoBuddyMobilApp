import SwiftUI

// Kategori buton komponenti için 
struct CategoryButton: View {
    let title: String
    let iconName: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// Logo dairesi bileşeni
struct CoinLogoCircle: View {
    let coin: Coin
    
    var body: some View {
        VStack(spacing: 5) {
            AsyncImage(url: URL(string: coin.image)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                } else if phase.error != nil {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .frame(width: 60, height: 60)
            .background(Circle().fill(Color.gray.opacity(0.1)))
            
            Text(coin.symbol)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
} 