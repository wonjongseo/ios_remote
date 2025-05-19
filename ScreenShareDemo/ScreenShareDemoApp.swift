//
//  ScreenShareDemoApp.swift
//  ScreenShareDemo
//
//  Created by Jongseo Won on 5/13/25.
//

import SwiftUI
import UserNotifications
import FirebaseCore

@main
struct ScreenShareDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
}


// MARK: - AppDelegate: APNs 등록 및 알림 처리
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let signalingServerUrl = "http://192.168.3.72:3000"
    
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
            
           
        // UNUserNotificationCenter 설정
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Firebase匿名認証
        FirebaseApp.configure()

        // 1) 알림 권한 요청
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("🔴 권한 요청 에러:", error.localizedDescription)
                return
            }
            if granted {
                DispatchQueue.main.async {
                    // 2) APNs 등록 요청
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("🔴 사용자가 알림 권한을 거부했습니다.")
            }
        }

        return true
    }
    
    // MARK: - APNs 등록 성공
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Data → Hex String 변환
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🟢 Device Token:", token)
        sendTokenToServer(token)
    }
    
    // MARK: - APNs 등록 실패
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔴 APNs 등록 실패:", error.localizedDescription)
    }
    
    // 서버에 토큰 전송
    private func sendTokenToServer(_ token: String) {
        guard let url = URL(string: "\(signalingServerUrl)/api/register-device") else {
            print("🔴 잘못된 서버 URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let json = ["token": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔴 토큰 전송 에러:", error.localizedDescription)
            } else if let resp = response as? HTTPURLResponse {
                print("🟢 서버 응답 상태:", resp.statusCode)
            }
        }.resume()
    }
    
    // MARK: - Foreground 알림 처리
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                   @escaping (UNNotificationPresentationOptions) -> Void) {
        // 앱이 포그라운드일 때에도 배너, 사운드, 배지 표시
        completionHandler([.banner, .sound, .badge])
    }
}

