import SwiftUI

struct NewsView: View {
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    private let darkBackgroundColor = Color(red: 0.11, green: 0.11, blue: 0.118)
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBackgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Kripto Haberler")
                        .font(.largeTitle)
                        .foregroundColor(goldColor)
                        .padding()
                        
                    Text("Bu bölüm yakında kullanıma açılacaktır.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Haberler")
        }
    }
} 