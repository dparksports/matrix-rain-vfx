import SwiftUI

struct MatrixView: View {
    var body: some View {
        ZStack {
            MetalView()
                .background(Color.clear)
                .ignoresSafeArea()
            
            VStack {
                Button(action: {
                    NotificationCenter.default.post(name: .tuckUnderMenu, object: nil)
                }) {
                    Text("A")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 10)
                
                Spacer()
                
                Button(action: {
                    NotificationCenter.default.post(name: .tuckUnderDock, object: nil)
                }) {
                    Text("B")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 10)
            }
        }
    }
}


