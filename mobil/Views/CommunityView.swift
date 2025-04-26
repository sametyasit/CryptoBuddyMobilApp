import SwiftUI

struct CommunityView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Arka plan
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    // Haber feed'i
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(1...5, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 14) {
                                    // Kullanıcı bilgisi
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(AppColors.gold)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Crypto User \(index)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Text("\(index * 3) hours ago")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {}) {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color.gray)
                                        }
                                    }
                                    
                                    // Post içeriği
                                    Text(communityPostForIndex(index))
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .lineLimit(nil)
                                    
                                    // Gönderi görseli (her iki gönderide bir)
                                    if index % 2 == 0 {
                                        ZStack {
                                            Rectangle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(height: 180)
                                                .cornerRadius(16)
                                            
                                            // Kripto ikonları
                                            HStack(spacing: 24) {
                                                Image(systemName: iconForCommunityPost(index))
                                                    .font(.system(size: 40))
                                                    .foregroundColor(AppColors.gold)
                                            }
                                        }
                                    }
                                    
                                    // İşlem butonları
                                    HStack(spacing: 20) {
                                        Button(action: {}) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "heart")
                                                    .font(.system(size: 16))
                                                Text("\(index * 15)")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color.gray)
                                        }
                                        
                                        Button(action: {}) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "bubble.right")
                                                    .font(.system(size: 16))
                                                Text("\(index * 3)")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {}) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color.gray)
                                        }
                                    }
                                }
                                .padding()
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
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Community")
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "plus.bubble.fill")
                            .foregroundColor(AppColors.gold)
                            .imageScale(.large)
                    }
                }
            }
        }
    }
    
    private func communityPostForIndex(_ index: Int) -> String {
        let posts = [
            "Just bought some more #Bitcoin on the dip! Looking like a great entry point right now. What do you all think?",
            "Has anyone checked out the new DeFi protocol that launched yesterday? Impressive APY so far but I'm cautious.",
            "NFT market seems to be recovering slowly. I've seen some interesting collections gaining traction again. #NFTs #CryptoArt",
            "Ethereum gas fees are finally reasonable again! Managed to move some assets for under $5. #ETH",
            "What are your thoughts on the upcoming regulations? I think some clarity might actually be good for the market in the long run."
        ]
        
        return posts[min(index - 1, posts.count - 1)]
    }
    
    private func iconForCommunityPost(_ index: Int) -> String {
        let icons = ["bitcoinsign.circle.fill", "ethereum", "arrow.triangle.2.circlepath.circle.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis.circle.fill"]
        return icons[min(index % icons.count, icons.count - 1)]
    }
} 