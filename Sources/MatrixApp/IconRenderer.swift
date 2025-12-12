import Metal
import MetalKit
import Cocoa

class IconRenderer {
    let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    
    var dockItems: [DockItem] = []
    var iconTextures: [MTLTexture?] = []
    
    // Layout constants
    let baseSize: CGFloat = 64
    let dividerWidth: CGFloat = 2
    let spacing: CGFloat = 10
    
    init?(device: MTLDevice) {
        self.device = device
        setupPipeline()
    }
    
    func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "iconVertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "iconFragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func update(with items: [DockItem]) {
        self.dockItems = items
        self.iconTextures = items.map { item in
            createTexture(from: item.icon)
        }
    }
    
    func createTexture(from image: NSImage) -> MTLTexture? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        
        let loader = MTKTextureLoader(device: device)
        // Load with origin bottom left to match standard UVs
        return try? loader.newTexture(data: data, options: [.origin: MTKTextureLoader.Origin.bottomLeft])
    }
    
    func render(to texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let pipelineState = pipelineState else { return }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        
        let width = CGFloat(texture.width)
        let height = CGFloat(texture.height)
        
        // Calculate total width to center items
        var totalW: CGFloat = 0
        for item in dockItems {
            let isDivider = (item.type == .divider)
            totalW += isDivider ? dividerWidth : baseSize
            totalW += spacing
        }
        totalW -= spacing
        
        var currentX: CGFloat = (width - totalW) / 2
        
        for (i, item) in dockItems.enumerated() {
            let isDivider = (item.type == .divider)
            let w = isDivider ? dividerWidth : baseSize
            let h = isDivider ? baseSize * 0.8 : baseSize
            
            if !isDivider, let iconTexture = iconTextures[i] {
                var rect = SIMD4<Float>(Float(currentX), Float((height - h) / 2), Float(w), Float(h))
                var viewport = SIMD2<Float>(Float(width), Float(height))
                
                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
                encoder.setFragmentTexture(iconTexture, index: 0)
                
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            
            currentX += w + spacing
        }
        
        encoder.endEncoding()
    }
}
