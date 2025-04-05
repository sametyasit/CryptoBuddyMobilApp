import SwiftUI

struct ProfileView: View {
    @State private var isLoggedIn = false
    @State private var username = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        if isLoggedIn {
            loggedInView
        } else {
            loginView
        }
    }
    
    var loggedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(AppColors.gold)
            
            Text("Welcome, \(username)")
                .font(.title)
                .foregroundColor(.white)
            
            Button(action: {
                isLoggedIn = false
            }) {
                Text("Log Out")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.gold)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.black)
    }
    
    var loginView: some View {
        VStack(spacing: 20) {
            Text("CryptoBuddy")
                .font(.largeTitle)
                .foregroundColor(AppColors.gold)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: {
                if username.isEmpty || password.isEmpty {
                    alertMessage = "Please fill in all fields"
                    showingAlert = true
                } else {
                    isLoggedIn = true
                }
            }) {
                Text("Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.gold)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.black)
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    ProfileView()
} 