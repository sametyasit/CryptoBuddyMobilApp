import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = 0
    @State private var birthDay = ""
    @State private var birthMonth = ""
    @State private var birthYear = ""
    @State private var tcNo = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var agreeTerms = false
    
    let genders = ["Erkek", "Kadın", "Diğer"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo ve başlık
                        Text("CryptoBuddy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(AppColorsTheme.gold)
                            .padding(.top, 20)
                        
                        Text("Hesap Oluştur")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        // Kayıt formu
                        VStack(spacing: 20) {
                            // Kullanıcı adı
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Kullanıcı Adı")
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                
                                TextField("", text: $firstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                            }
                            
                            // E-posta
                            VStack(alignment: .leading, spacing: 8) {
                                Text("E-posta")
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                
                                TextField("", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }
                            
                            // Şifre
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Şifre")
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                
                                SecureField("", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // Şifre tekrar
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Şifre Tekrar")
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                
                                SecureField("", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // Koşulları kabul et
                            Toggle(isOn: $agreeTerms) {
                                Text("Kullanım koşullarını kabul ediyorum")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .toggleStyle(CheckboxToggleStyle())
                            .padding(.vertical, 10)
                            
                            // Kayıt ol butonu
                            Button(action: {
                                // Form doğrulama
                                if firstName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty {
                                    alertMessage = "Lütfen tüm alanları doldurun"
                                    showingAlert = true
                                    return
                                }
                                
                                if !isValidEmail(email) {
                                    alertMessage = "Lütfen geçerli bir e-posta adresi girin"
                                    showingAlert = true
                                    return
                                }
                                
                                if password != confirmPassword {
                                    alertMessage = "Şifreler eşleşmiyor"
                                    showingAlert = true
                                    return
                                }
                                
                                if !agreeTerms {
                                    alertMessage = "Devam etmek için kullanım koşullarını kabul etmelisiniz"
                                    showingAlert = true
                                    return
                                }
                                
                                // Kayıt işlemi başarılı
                                alertMessage = "Hesabınız başarıyla oluşturuldu"
                                showingAlert = true
                            }) {
                                Text("Kayıt Ol")
                                    .foregroundColor(.black)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColorsTheme.gold)
                                    .cornerRadius(10)
                            }
                            
                            // Zaten hesabınız var mı?
                            HStack {
                                Text("Zaten hesabınız var mı?")
                                    .foregroundColor(.gray)
                                
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Text("Giriş Yap")
                                        .foregroundColor(AppColorsTheme.gold)
                                        .underline()
                                }
                            }
                            .font(.subheadline)
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 25)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .imageScale(.large)
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertMessage.contains("başarı") ? "Başarılı" : "Hata"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Tamam")) {
                        if alertMessage.contains("başarı") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func validateAndRegister() {
        // Doğum tarihi kontrolü
        if !validateBirthDate() {
            return
        }
        
        // TC Kimlik No kontrolü
        if tcNo.count != 11 {
            alertMessage = "T.C. Kimlik No 11 haneli olmalıdır."
            isSuccess = false
            showingAlert = true
            return
        }
        
        // E-posta kontrolü
        if !email.contains("@") || !email.contains(".") {
            alertMessage = "Geçerli bir e-posta adresi giriniz."
            isSuccess = false
            showingAlert = true
            return
        }
        
        // Şifre kontrolü
        if password.count < 6 {
            alertMessage = "Şifre en az 6 karakter olmalıdır."
            isSuccess = false
            showingAlert = true
            return
        }
        
        if password != confirmPassword {
            alertMessage = "Şifreler eşleşmiyor."
            isSuccess = false
            showingAlert = true
            return
        }
        
        // Başarılı kayıt
        alertMessage = "Hesabınız başarıyla oluşturuldu."
        isSuccess = true
        showingAlert = true
    }
    
    private func validateBirthDate() -> Bool {
        // Gün, ay ve yıl alanları boş olmamalı
        if birthDay.isEmpty || birthMonth.isEmpty || birthYear.isEmpty {
            alertMessage = "Lütfen doğum tarihinizi tam olarak giriniz."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        // Sayısal değerler olmalı
        guard let day = Int(birthDay), let month = Int(birthMonth), let year = Int(birthYear) else {
            alertMessage = "Doğum tarihi için geçerli sayısal değerler giriniz."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        // Geçerlilik kontrolleri
        if day < 1 || day > 31 {
            alertMessage = "Gün değeri 1-31 arasında olmalıdır."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        if month < 1 || month > 12 {
            alertMessage = "Ay değeri 1-12 arasında olmalıdır."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        if year < 1900 || year > currentYear {
            alertMessage = "Geçerli bir doğum yılı giriniz."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        // Geçerli bir tarih olmalı
        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = year
        
        if Calendar.current.date(from: dateComponents) == nil {
            alertMessage = "Geçerli bir tarih giriniz."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        // 18 yaş kontrolü
        let birthDate = Calendar.current.date(from: dateComponents)!
        let now = Date()
        let ageComponents = Calendar.current.dateComponents([.year], from: birthDate, to: now)
        
        if let age = ageComponents.year, age < 18 {
            alertMessage = "Kayıt olmak için 18 yaşından büyük olmalısınız."
            isSuccess = false
            showingAlert = true
            return false
        }
        
        return true
    }
    
    // E-posta formatı kontrolü için basit bir doğrulama
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// Özel checkbox toggle stili
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(configuration.isOn ? AppColorsTheme.gold : .gray)
                .onTapGesture {
                    withAnimation {
                        configuration.isOn.toggle()
                    }
                }
            configuration.label
        }
    }
}

#Preview {
    SignUpView()
} 