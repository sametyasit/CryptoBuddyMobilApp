import SwiftUI

struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Arka plan
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    // Toplam değer kartı
                    VStack(spacing: 8) {
                        Text("Total Portfolio Value")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.gray)
                        
                        Text("$24,856.73")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.green)
                            
                            Text("+3.2% ($789.23)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)), Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // Alarm paneli
                    HStack(spacing: 15) {
                        Button(action: {}) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.gold)
                                
                                Text("Deposit")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.darkGray).opacity(0.5))
                            )
                        }
                        
                        Button(action: {}) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.gold)
                                
                                Text("Send")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.darkGray).opacity(0.5))
                            )
                        }
                        
                        Button(action: {}) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.left.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.gold)
                                
                                Text("Receive")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.darkGray).opacity(0.5))
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Varlık listesi başlığı
                    HStack {
                        Text("Your Assets")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Text("See All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.gold)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Coin listesi
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(["Bitcoin", "Ethereum", "Solana"], id: \.self) { coin in
                                HStack {
                                    // Coin ikonu
                                    Image(systemName: iconForCoin(coin))
                                        .font(.system(size: 32))
                                        .foregroundColor(colorForCoin(coin))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(colorForCoin(coin).opacity(0.15))
                                        )
                                    
                                    // Coin bilgileri
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(coin)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text(symbolForCoin(coin))
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    // Fiyat bilgileri
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(amountForCoin(coin))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text(valueForCoin(coin))
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.darkGray).opacity(0.3))
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLoginView = true
                    }) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppColors.gold)
                            .imageScale(.large)
                    }
                }
            }
        }
    }
    
    private func iconForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "bitcoinsign.circle.fill"
            case "Ethereum": return "ethereum"
            case "Solana": return "s.circle.fill"
            default: return "questionmark.circle"
        }
    }
    
    private func colorForCoin(_ coin: String) -> Color {
        switch coin {
            case "Bitcoin": return AppColors.gold
            case "Ethereum": return Color.purple
            case "Solana": return Color.green
            default: return Color.gray
        }
    }
    
    private func symbolForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "BTC"
            case "Ethereum": return "ETH"
            case "Solana": return "SOL"
            default: return "???"
        }
    }
    
    private func amountForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "0.42 BTC"
            case "Ethereum": return "3.21 ETH"
            case "Solana": return "24.5 SOL"
            default: return "0.00"
        }
    }
    
    private func valueForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "$15,750.32"
            case "Ethereum": return "$7,452.26"
            case "Solana": return "$1,654.15"
            default: return "$0.00"
        }
    }
} 