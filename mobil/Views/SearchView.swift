import SwiftUI

struct SearchView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            // Arka plan
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Arama kutusu
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.gray)
                        .padding(.leading, 10)
                    
                    TextField("Search coins, news...", text: .constant(""))
                        .foregroundColor(.white)
                        .padding(10)
                    
                    Button(action: {}) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray)
                            .padding(.trailing, 10)
                    }
                }
                .background(Color(UIColor.darkGray).opacity(0.3))
                .cornerRadius(15)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // İçerik
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Popular Searches")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        // Popüler aramalar
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(["Bitcoin", "Ethereum", "XRP", "Solana", "Cardano"], id: \.\self) { item in
                                    Text(item)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(AppColors.gold.opacity(0.15))
                                        .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Text("Popular Categories")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        // Kategoriler
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(["DeFi", "NFTs", "Metaverse", "GameFi", "Layer-1", "Stablecoins"], id: \.\self) { category in
                                VStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(height: 110)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: iconForCategory(category))
                                                    .font(.system(size: 36))
                                                    .foregroundColor(AppColors.gold)
                                                Text(category)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Search")
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
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
            case "DeFi": return "chart.line.uptrend.xyaxis"
            case "NFTs": return "square.grid.3x3.fill"
            case "Metaverse": return "headset"
            case "GameFi": return "gamecontroller.fill"
            case "Layer-1": return "square.stack.3d.up.fill"
            case "Stablecoins": return "dollarsign.circle.fill"
            default: return "questionmark.circle"
        }
    }
} 