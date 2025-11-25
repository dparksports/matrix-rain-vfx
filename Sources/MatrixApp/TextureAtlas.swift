import Metal
import MetalKit

class TextureAtlas {
    let texture: MTLTexture
    let atlasDimensions: SIMD2<Float> // cols, rows
    
    init(device: MTLDevice, imageName: String) throws {
        let textureLoader = MTKTextureLoader(device: device)
        
        guard let url = Bundle.module.url(forResource: imageName, withExtension: "png") else {
             throw NSError(domain: "TextureAtlas", code: 1, userInfo: [NSLocalizedDescriptionKey: "Image not found: \(imageName)"])
        }
        
        self.texture = try textureLoader.newTexture(URL: url, options: [
            .origin: MTKTextureLoader.Origin.topLeft
        ])
        
        // Hardcoded for the provided image 8x8
        self.atlasDimensions = SIMD2<Float>(8, 8)
    }
}
