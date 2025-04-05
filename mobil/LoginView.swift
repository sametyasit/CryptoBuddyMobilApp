import SwiftUI

struct LoginView: View {
    @Binding var isPresented: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // Logo ve başlık
                    Text("CryptoBuddy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.gold)
                        .padding(.top, 50)
                    
                    Spacer()
                    
                    // Giriş formu
                    VStack(spacing: 25) {
                        // Kullanıcı adı
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .foregroundColor(.white)
                                .font(.footnote)
                            
                            TextField("", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        
                        // Şifre
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .foregroundColor(.white)
                                .font(.footnote)
                            
                            SecureField("", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Şifremi unuttum
                        Button(action: {
                            showingForgotPassword = true
                        }) {
                            Text("Şifremi unuttum")
                                .foregroundColor(AppColors.gold)
                                .font(.footnote)
                                .underline()
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        // Giriş butonu
                        Button(action: {
                            // Login işlemi
                            if username == "admin" && password == "1234" {
                                isLoggedIn = true
                                isPresented = false
                            } else {
                                showingAlert = true
                            }
                        }) {
                            Text("Login")
                                .foregroundColor(.black)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.gold)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    Spacer()
                    
                    // Hesap oluştur
                    HStack {
                        Text("Hesabınız yok mu?")
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showingSignUp = true
                        }) {
                            Text("Hesap Oluştur")
                                .foregroundColor(AppColors.gold)
                                .underline()
                        }
                    }
                    .font(.subheadline)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarItems(leading: Button(action: {
                isPresented = false
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(AppColors.gold)
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Hata"),
                    message: Text("Kullanıcı adı veya şifre hatalı"),
                    dismissButton: .default(Text("Tamam"))
                )
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("Şifre Sıfırlama")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Lütfen kayıtlı e-posta adresinizi girin")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // E-posta TextField
                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-posta")
                            .foregroundColor(.white)
                            .font(.footnote)
                        
                        TextField("", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    .padding(.horizontal)
                    
                    // Şifre sıfırlama butonu
                    Button(action: {
                        // Şifre sıfırlama e-postası gönderme işlemi
                        showingAlert = true
                    }) {
                        Text("Şifre Sıfırlama\nBağlantısı Gönder")
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.gold)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.gold)
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Başarılı"),
                    message: Text("Şifre sıfırlama bağlantısı e-posta adresinize gönderildi."),
                    dismissButton: .default(Text("Tamam")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}

#Preview {
    LoginView(isPresented: .constant(true))
} 