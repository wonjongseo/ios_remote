import SwiftUI
import ReplayKit

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        
        VStack(spacing: 20) {
                   if authVM.isLoading {
                       ProgressView("ログイン中。。。")
                   }
                   else if let user = authVM.user {
                       Text("匿名認証成功 🎉")
                       Text("UID: \(user.uid)")
                           .font(.caption)
                           .foregroundColor(.gray)
                       
                       VStack(spacing: 20) {
                           Text("画面共有")
                               .font(.title)
                       
                           Button("スタット") {
                               startScreenShare()
                           }
                       }
                       .padding(.bottom, 20)
                       Button("ログアウト") { authVM.signOut() }
                   }
                   else {
                       Text("익명 로그인 상태가 아닙니다.")
                       Button("익명 로그인 시작") { authVM.signInAnonymously() }
                   }

                   if let err = authVM.errorMessage {
                       Text("エラー: \(err)")
                           .foregroundColor(.red)
                           .font(.caption)
                   }
               }
               .padding()
        

    }

    func startScreenShare() {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        picker.preferredExtension = "com.wonjongseo.remotecontroler.ScreenShareUploader" //com.wonjongseo.ScreenShareDemo.ScreenShareUploader" //

        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.sendActions(for: .allEvents)
        }
    }
}

#Preview {
    ContentView()
}
