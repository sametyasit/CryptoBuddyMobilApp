import SwiftUI

struct MarketView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            CoinListView()
                .navigationTitle("Markets")
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
} 