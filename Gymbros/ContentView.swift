//
//  ContentView.swift
//  Gymbros
//
//  Created by Nattapong Sawatraksa on 17/5/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?
    
    enum Field { case email, password }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                // Branding / Title
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell")
                        .symbolVariant(.fill)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.tint)
                    Text("Welcome to Gymbros")
                        .font(.title.bold())
                }
                
                // Form fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                        .submitLabel(.next)
                        .focused($focusedField, equals: Field.email)
                        .padding(12)
                        .background(Material.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: Field.password)
                        .padding(12)
                        .background(Material.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal)
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isLoading ? "Signing In…" : "Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    Button("Create an account") {
                        // Hook up to sign-up flow when available
                    }
                    .font(.callout)
                }
                
                Spacer()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onSubmit {
                switch focusedField {
                case .email:
                    focusedField = Field.password
                case .password:
                    signIn()
                case .none:
                    break
                }
            }
        }
    }
    
    func signIn() {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        
        // Basic email format check
        if !email.contains("@") || !email.contains(".") {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        isLoading = true
        // Simulate async sign-in; replace with real auth as needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isLoading = false
            // For demo purposes, accept any non-empty credentials
            print("Signed in as: \(email)")
        }
    }
}

#Preview {
    ContentView()
}
