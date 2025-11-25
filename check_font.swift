import AppKit
import CoreText

let path = "Sources/MatrixApp/Resources/Matrix-Code.ttf"
let url = URL(fileURLWithPath: path)

if let provider = CGDataProvider(url: url as CFURL),
   let font = CGFont(provider) {
    print("PostScript Name: \(font.postScriptName as String? ?? "nil")")
    print("Full Name: \(font.fullName as String? ?? "nil")")
} else {
    print("Failed to load font")
}
