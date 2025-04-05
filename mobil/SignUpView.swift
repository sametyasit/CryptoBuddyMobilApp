import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = 0
    @State private var birthDate = Date()
    @State private var tcNo = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    let genders = ["Erkek", "Kadın", "Diğer"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Hesap Oluştur")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        Group {
                            TextField("Ad", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Soyad", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Picker("Cinsiyet", selection: $gender) {
                                ForEach(0..<genders.count) { index in
                                    Text(genders[index]).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            
                            DatePicker("Doğum Tarihi",
                                     selection: $birthDate,
                                     in: ...Date(),
                                     displayedComponents: .date)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            
                            TextField("T.C. Kimlik No", text: $tcNo)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            TextField("E-posta", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            SecureField("Şifre", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            SecureField("Şifre (Tekrar)", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        Button(action: validateAndRegister) {
                            Text("Kayıt Ol")
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.gold)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .padding(.bottom, 50)
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
                    title: Text(isSuccess ? "Başarılı" : "Hata"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Tamam")) {
                        if isSuccess {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func validateAndRegister() {
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
}

#Preview {
    SignUpView()
} 