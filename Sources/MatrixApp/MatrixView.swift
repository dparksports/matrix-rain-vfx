import SwiftUI

struct MatrixView: View {
    var body: some View {
        ZStack {
            MetalView()
                .background(Color.clear)
                .ignoresSafeArea()
            
            HStack {
                VStack(spacing: 5) {
                    // W Button (Top)
                    Button(action: {
                        NotificationCenter.default.post(name: .tuckUnderMenu, object: nil)
                    }) {
                        Text("W")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack(spacing: 5) {
                        // A Button (Left)
                        Button(action: {
                            NotificationCenter.default.post(name: .tuckLeft, object: nil)
                        }) {
                            Text("A")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // S Button (Bottom)
                        Button(action: {
                            NotificationCenter.default.post(name: .tuckUnderDock, object: nil)
                        }) {
                            Text("S")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // D Button (Right)
                        Button(action: {
                            NotificationCenter.default.post(name: .tuckRight, object: nil)
                        }) {
                            Text("D")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.leading, 10) // Add some padding from the edge
                
                Spacer()
            }
        }
    }
}


