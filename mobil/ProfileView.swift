import SwiftUI

struct ProfileView: View {
    @State private var name = "John Doe"
    @State private var email = "johndoe@example.com"
    @State private var bio = "Crypto Enthusiast & Investor"
    @State private var isEditing = false
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        VStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(AppColorsTheme.gold)
                                .padding(.bottom, 5)
                            
                            Text(name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.bottom, 10)
                            
                            if !isEditing {
                                Button("Profili Düzenle") {
                                    isEditing = true
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(AppColorsTheme.gold)
                                .cornerRadius(20)
                            }
                        }
                        .padding()
                        .background(AppColorsTheme.black)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        
                        // Profile Edit Form
                        if isEditing {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Profil Bilgileri")
                                    .font(.headline)
                                    .foregroundColor(AppColorsTheme.gold)
                                    .padding(.vertical, 5)
                                
                                // Name Field
                                VStack(alignment: .leading) {
                                    Text("Ad Soyad")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    TextField("", text: $name)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                // Email Field
                                VStack(alignment: .leading) {
                                    Text("Email")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    TextField("", text: $email)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                                
                                // Bio Field
                                VStack(alignment: .leading) {
                                    Text("Bio")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    TextEditor(text: $bio)
                                        .frame(height: 100)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                }
                                
                                // Save Button
                                Button("Değişiklikleri Kaydet") {
                                    isEditing = false
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(AppColorsTheme.gold)
                                .cornerRadius(20)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 10)
                            }
                            .padding()
                            .background(AppColorsTheme.black)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                        }
                        
                        // Logout Button
                        Button(action: {
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Çıkış Yap")
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(Color(UIColor.darkGray).opacity(0.3))
                            .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showLogoutConfirmation) {
                Alert(
                    title: Text("Çıkış Yap"),
                    message: Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?"),
                    primaryButton: .destructive(Text("Çıkış Yap")) {
                        // Perform logout action
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

#Preview {
    ProfileView()
} 