//
//  AuthViewModel.swift
//  ScreenShareDemo
//
//  Created by Jongseo Won on 5/19/25.
//

import Foundation
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 익명 로그인
    func signInAnonymously() {
        isLoading = true
        errorMessage = nil

        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    print(error)
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.user = result?.user
                }
            }
        }
    }

    /// 로그아웃
    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
