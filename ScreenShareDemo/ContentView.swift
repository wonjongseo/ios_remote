import SwiftUI
import ReplayKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("iOS 시스템 전체 화면 공유")
                .font(.title)

            Button("화면 공유 시작") {
                startScreenShare()
            }
        }
        .padding()
    }

    func startScreenShare() {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        picker.preferredExtension = "com.wonjongseo.ScreenShareDemo.ScreenShareUploader" // ⚠️ 여기는 실제 확장 번들 ID로 바꿔야 함

        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.sendActions(for: .allEvents)
        }
    }
}

#Preview {
    ContentView()
}
