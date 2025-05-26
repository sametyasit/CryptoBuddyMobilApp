import SwiftUI
import Foundation

struct ProfileView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    @State private var username = ""
    @State private var email = ""
    @State private var showingEditProfile = false
    @State private var userCommentCount = 0
    @State private var userLikesReceived = 0
    @State private var showingNotifications = false
    @State private var showingPrivacy = false
    @State private var showingHelp = false
    @State private var profileImageData: Data?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !isLoggedIn {
                    // Giriş yapmayan kullanıcılar için
                    VStack(spacing: 25) {
                        Image(systemName: "person.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(AppColorsTheme.gold)
                        
                        Text("Profilinizi görüntülemek için giriş yapın")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Hesabınıza giriş yaparak profilinizi görüntüleyebilir ve düzenleyebilirsiniz.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Text("Giriş Yap")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(AppColorsTheme.gold)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 50)
                        .padding(.top, 20)
                    }
                    .padding()
                } else {
                    // Giriş yapmış kullanıcılar için profil
                    ScrollView {
                        VStack(spacing: 20) {
                                                        // Profil başlığı
                            VStack(spacing: 16) {
                            // Profil fotoğrafı
                            if let imageData = profileImageData,
                               let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(AppColorsTheme.gold, lineWidth: 3))
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(AppColorsTheme.gold)
                            }
                                
                                VStack(spacing: 8) {
                                    Text(username)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Button(action: {
                                    showingEditProfile = true
                                }) {
                                    Text("Profili Düzenle")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(AppColorsTheme.gold)
                                        .cornerRadius(20)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6).opacity(0.2))
                            .cornerRadius(16)
                            .padding(.horizontal)
                            
                            // İstatistikler
                            VStack(alignment: .leading, spacing: 16) {
                                Text("İstatistikler")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    StatCard(
                                        title: "Toplam Yorum",
                                        value: "\(userCommentCount)",
                                        icon: "message.fill"
                                    )
                                    
                                    StatCard(
                                        title: "Alınan Beğeni",
                                        value: "\(userLikesReceived)",
                                        icon: "heart.fill"
                                    )
                                    
                                    StatCard(
                                        title: "Üyelik Süresi",
                                        value: "Yeni Üye",
                                        icon: "calendar"
                                    )
                                    
                                    StatCard(
                                        title: "Seviye",
                                        value: "Başlangıç",
                                        icon: "star.fill"
                                    )
                                }
                                .padding(.horizontal)
                            }
                            
                            // Hesap ayarları
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Hesap Ayarları")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    Button(action: {
                                        showingNotifications = true
                                    }) {
                                        SettingsRow(
                                            icon: "bell.fill",
                                            title: "Bildirimler",
                                            subtitle: "Push bildirimleri yönet"
                                        )
                                    }
                                    
                                    Button(action: {
                                        showingPrivacy = true
                                    }) {
                                        SettingsRow(
                                            icon: "lock.fill",
                                            title: "Gizlilik",
                                            subtitle: "Gizlilik ayarları"
                                        )
                                    }
                                    
                                    Button(action: {
                                        showingHelp = true
                                    }) {
                                        SettingsRow(
                                            icon: "questionmark.circle.fill",
                                            title: "Yardım",
                                            subtitle: "SSS ve destek"
                                        )
                                    }
                                    
                                    Button(action: {
                                        logOut()
                                    }) {
                                        HStack {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .foregroundColor(.red)
                                            
                                            Text("Çıkış Yap")
                                                .foregroundColor(.red)
                                                .font(.headline)
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(UIColor.systemGray6).opacity(0.2))
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.bottom, 30)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkLoginStatus()
                calculateUserStats()
            }
            .onChange(of: showingLoginView) { oldValue, newValue in
                checkLoginStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserLoggedIn"))) { _ in
                checkLoginStatus()
                calculateUserStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProfileUpdated"))) { _ in
                checkLoginStatus()
                calculateUserStats()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(username: $username, email: $email)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyView()
            }
            .sheet(isPresented: $showingHelp) {
                HelpView()
            }
        }
    }
    
    private func checkLoginStatus() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn {
            username = UserDefaults.standard.string(forKey: "username") ?? "Kullanıcı"
            email = UserDefaults.standard.string(forKey: "userEmail") ?? "user@example.com"
            loadProfileImage()
        }
    }
    
    private func loadProfileImage() {
        profileImageData = UserDefaults.standard.data(forKey: "profileImageData")
    }
    
    private func calculateUserStats() {
        guard isLoggedIn else { return }
        
        // Kullanıcının yorum sayısını hesapla
        if let data = UserDefaults.standard.data(forKey: "communityComments"),
           let comments = try? JSONDecoder().decode([CommunityComment].self, from: data) {
            
            userCommentCount = comments.filter { $0.username == username }.count
            userLikesReceived = comments.filter { $0.username == username }.reduce(0) { $0 + $1.likes }
        }
    }
    
    private func logOut() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        isLoggedIn = false
        userCommentCount = 0
        userLikesReceived = 0
    }
}

// İstatistik kartı
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColorsTheme.gold)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
}

// Ayarlar satırı
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColorsTheme.gold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
}

// Profil düzenleme sayfası
struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var username: String
    @Binding var email: String
    @State private var newUsername: String = ""
    @State private var newEmail: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var profileImageData: Data?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Profil resmi
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        ZStack {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(AppColorsTheme.gold, lineWidth: 3))
                            } else if let imageData = profileImageData, let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(AppColorsTheme.gold, lineWidth: 3))
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(AppColorsTheme.gold)
                            }
                            
                            // Kamera ikonu
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(AppColorsTheme.gold)
                                        .clipShape(Circle())
                                        .offset(x: -5, y: -5)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form alanları
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kullanıcı Adı")
                                .foregroundColor(.white)
                                .font(.footnote)
                            
                            TextField("", text: $newUsername)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("E-posta")
                                .foregroundColor(.white)
                                .font(.footnote)
                            
                            TextField("", text: $newEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Kaydet butonu
                    Button(action: {
                        saveProfile()
                    }) {
                        Text("Kaydet")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppColorsTheme.gold)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Profili Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("İptal") {
                    presentationMode.wrappedValue.dismiss()
                }.foregroundColor(AppColorsTheme.gold),
                trailing: Button("Kaydet") {
                    saveProfile()
                }.foregroundColor(AppColorsTheme.gold)
            )
            .onAppear {
                newUsername = username
                newEmail = email
                loadProfileImage()
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Bilgi"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Tamam")) {
                        if alertMessage.contains("başarı") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    profileImageData = image.jpegData(compressionQuality: 0.8)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard !newUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Kullanıcı adı boş olamaz"
            showingAlert = true
            return
        }
        
        guard !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "E-posta boş olamaz"
            showingAlert = true
            return
        }
        
        // E-posta formatı kontrolü
        if !isValidEmail(newEmail) {
            alertMessage = "Lütfen geçerli bir e-posta adresi girin"
            showingAlert = true
            return
        }
        
        // Profili kaydet
        username = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(email, forKey: "userEmail")
        
        // Profil fotoğrafını kaydet
        if let imageData = profileImageData {
            UserDefaults.standard.set(imageData, forKey: "profileImageData")
        }
        
        // Profil güncellendiğini bildir
        NotificationCenter.default.post(name: Notification.Name("ProfileUpdated"), object: nil)
        
        alertMessage = "Profil başarıyla güncellendi"
        showingAlert = true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func loadProfileImage() {
        if let imageData = UserDefaults.standard.data(forKey: "profileImageData") {
            profileImageData = imageData
        }
    }
}

// MARK: - Bildirimler Sayfası
struct NotificationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var pushNotifications = true
    @State private var emailNotifications = false
    @State private var priceAlerts = true
    @State private var newsAlerts = false
    @State private var communityNotifications = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Bildirim Ayarları
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bildirim Türleri")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                NotificationToggleRow(
                                    icon: "bell.fill",
                                    title: "Push Bildirimleri",
                                    subtitle: "Anlık bildirimler al",
                                    isOn: $pushNotifications
                                )
                                
                                NotificationToggleRow(
                                    icon: "envelope.fill",
                                    title: "E-posta Bildirimleri",
                                    subtitle: "E-posta ile bildirim al",
                                    isOn: $emailNotifications
                                )
                                
                                NotificationToggleRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    title: "Fiyat Uyarıları",
                                    subtitle: "Fiyat değişimlerinde bildir",
                                    isOn: $priceAlerts
                                )
                                
                                NotificationToggleRow(
                                    icon: "newspaper.fill",
                                    title: "Haber Bildirimleri",
                                    subtitle: "Yeni haberlerden haberdar ol",
                                    isOn: $newsAlerts
                                )
                                
                                NotificationToggleRow(
                                    icon: "person.3.fill",
                                    title: "Topluluk Bildirimleri",
                                    subtitle: "Yorumlara gelen yanıtlar",
                                    isOn: $communityNotifications
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Bildirim Zamanları
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bildirim Zamanları")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                InfoCard(
                                    icon: "clock.fill",
                                    title: "Sessiz Saatler",
                                    subtitle: "22:00 - 08:00 arası bildirim yok"
                                )
                                
                                InfoCard(
                                    icon: "calendar",
                                    title: "Hafta Sonu",
                                    subtitle: "Hafta sonu bildirimleri azaltılmış"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Bildirimler")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(AppColorsTheme.gold))
        }
    }
}

// MARK: - Gizlilik Sayfası
struct PrivacyView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var dataCollection = false
    @State private var analytics = true
    @State private var profileVisibility = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Gizlilik Ayarları
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Veri Gizliliği")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                NotificationToggleRow(
                                    icon: "shield.fill",
                                    title: "Veri Toplama",
                                    subtitle: "Kişisel veri toplamaya izin ver",
                                    isOn: $dataCollection
                                )
                                
                                NotificationToggleRow(
                                    icon: "chart.bar.fill",
                                    title: "Analitik Veriler",
                                    subtitle: "Uygulama kullanım verilerini paylaş",
                                    isOn: $analytics
                                )
                                
                                NotificationToggleRow(
                                    icon: "eye.fill",
                                    title: "Profil Görünürlüğü",
                                    subtitle: "Profilini diğer kullanıcılara göster",
                                    isOn: $profileVisibility
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Gizlilik Politikası
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Gizlilik Politikası")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                InfoCard(
                                    icon: "doc.text.fill",
                                    title: "Gizlilik Sözleşmesi",
                                    subtitle: "Gizlilik politikamızı okuyun"
                                )
                                
                                InfoCard(
                                    icon: "trash.fill",
                                    title: "Veri Silme",
                                    subtitle: "Hesabınızı ve verilerinizi silin"
                                )
                                
                                InfoCard(
                                    icon: "square.and.arrow.down.fill",
                                    title: "Veri İndirme",
                                    subtitle: "Kişisel verilerinizi indirin"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Gizlilik")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(AppColorsTheme.gold))
        }
    }
}

// MARK: - Yardım Sayfası
struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // SSS
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Sık Sorulan Sorular")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                FAQCard(
                                    question: "Nasıl coin satın alabilirim?",
                                    answer: "CryptoBuddy bir takip uygulamasıdır. Coin satın almak için güvenilir borsaları kullanmanızı öneririz."
                                )
                                
                                FAQCard(
                                    question: "Verilerim güvende mi?",
                                    answer: "Evet, tüm verileriniz şifrelenerek saklanır ve üçüncü taraflarla paylaşılmaz."
                                )
                                
                                FAQCard(
                                    question: "Fiyat uyarıları nasıl çalışır?",
                                    answer: "Belirttiğiniz fiyat seviyelerine ulaşıldığında otomatik bildirim alırsınız."
                                )
                                
                                FAQCard(
                                    question: "Hesabımı nasıl silerim?",
                                    answer: "Profil > Gizlilik > Veri Silme bölümünden hesabınızı kalıcı olarak silebilirsiniz."
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // İletişim
                        VStack(alignment: .leading, spacing: 16) {
                            Text("İletişim")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                InfoCard(
                                    icon: "envelope.fill",
                                    title: "E-posta Desteği",
                                    subtitle: "support@cryptobuddy.com"
                                )
                                
                                InfoCard(
                                    icon: "message.fill",
                                    title: "Canlı Destek",
                                    subtitle: "7/24 canlı destek hattı"
                                )
                                
                                InfoCard(
                                    icon: "star.fill",
                                    title: "Uygulama Değerlendir",
                                    subtitle: "App Store'da değerlendirin"
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Uygulama Bilgileri
                        VStack(spacing: 8) {
                            Text("CryptoBuddy v1.0.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("© 2024 CryptoBuddy. Tüm hakları saklıdır.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Yardım")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(AppColorsTheme.gold))
        }
    }
}

// MARK: - Yardımcı View'lar
struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColorsTheme.gold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppColorsTheme.gold))
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColorsTheme.gold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
}

struct FAQCard: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(AppColorsTheme.gold)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ProfileView(showingLoginView: .constant(false))
} 