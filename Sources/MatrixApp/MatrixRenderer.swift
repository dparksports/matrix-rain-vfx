import Metal
import MetalKit
import simd
import QuartzCore

struct InstanceData {
    var position: SIMD2<Float>
    var glyphIndex: Int32
    var brightness: Float
    var isHead: Float
    var padding: SIMD3<Float> = SIMD3<Float>(0,0,0)
}

struct Uniforms {
    var viewportSize: SIMD2<Float>
    var atlasDimensions: SIMD2<Float>
    var glyphSize: SIMD2<Float> // Added
}



class MatrixRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    // Pipelines
    var scenePipelineState: MTLRenderPipelineState!
    var highPassPipelineState: MTLRenderPipelineState!
    var blurPipelineState: MTLRenderPipelineState!
    var compositePipelineState: MTLRenderPipelineState!
    
    var textureAtlas: TextureAtlas!
    
    // Buffers
    var vertexBuffer: MTLBuffer!
    var instanceBuffer: MTLBuffer!
    
    // Textures
    var sceneTexture: MTLTexture?
    var bloomTexture1: MTLTexture?
    var bloomTexture2: MTLTexture?
    
    // Simulation State
    var grid: [[Int32]] = []
    var drops: [Drop] = []
    var cols: Int = 0
    var rows: Int = 0
    let fontSize: Float = Constants.fontSize
    var viewportSize: CGSize = .zero
    
    struct Drop {
        var y: Double
        var speed: Double
        var tailLength: Double
    }
    
    var lastTime: TimeInterval = 0
    // let characters = ... (Removed)
    
    var iconRenderer: IconRenderer?
    var iconTexture: MTLTexture?
    
    init?(metalKitView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        
        self.device = device
        self.commandQueue = queue
        super.init()
        
        metalKitView.device = device
        metalKitView.delegate = self
        metalKitView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1) // Opaque Black
        metalKitView.layer?.isOpaque = true
        metalKitView.framebufferOnly = false // Allow sampling from drawable if needed (though we use offscreen)
        
        setupPipelines()
        setupBuffers()
        
        // Load Texture Atlas
        do {
            textureAtlas = try TextureAtlas(device: device, imageName: "matrix_glyphs")
        } catch {
            print("Failed to load texture atlas: \(error)")
        }
        
        // Setup Icon Renderer
        iconRenderer = IconRenderer(device: device)
        let dockItems = IconManager.fetchDockItems()
        iconRenderer?.update(with: dockItems)
    }
    
    func setupPipelines() {
        var library: MTLLibrary?
        
        do {
            if let url = Bundle.module.url(forResource: "default", withExtension: "metallib") {
                library = try device.makeLibrary(URL: url)
            } else if let url = Bundle.module.url(forResource: "Shaders", withExtension: "metal") {
                let source = try String(contentsOf: url)
                library = try device.makeLibrary(source: source, options: nil)
            } else {
                library = device.makeDefaultLibrary()
            }
        } catch {
            print("Failed to load library: \(error)")
        }
        
        guard let library = library else { return }
        
        // Scene Pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 8
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = 16
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        scenePipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Post-Processing Pipelines (Quad)
        let quadDescriptor = MTLRenderPipelineDescriptor()
        quadDescriptor.vertexFunction = library.makeFunction(name: "quadVertexShader")
        quadDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // High Pass
        quadDescriptor.fragmentFunction = library.makeFunction(name: "highPassShader")
        highPassPipelineState = try? device.makeRenderPipelineState(descriptor: quadDescriptor)
        
        // Blur
        quadDescriptor.fragmentFunction = library.makeFunction(name: "blurShader")
        blurPipelineState = try? device.makeRenderPipelineState(descriptor: quadDescriptor)
        
        // Composite
        quadDescriptor.fragmentFunction = library.makeFunction(name: "compositeShader")
        // Enable blending for composite to output to drawable? No, we overwrite.
        // Actually, we want to blend with background if transparent window.
        // But composite shader outputs final color.
        // If we want transparency, composite shader needs to handle alpha correctly.
        // Our composite shader passes scene alpha.
        compositePipelineState = try? device.makeRenderPipelineState(descriptor: quadDescriptor)
    }
    
    func setupBuffers() {
        let vertices: [Float] = [
            0, 0, 0, 1,
            1, 0, 1, 1,
            0, 1, 0, 0,
            1, 1, 1, 0
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
        resizeGrid(size: size)
        createTextures(size: size)
    }
    
    func createTextures(size: CGSize) {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        sceneTexture = device.makeTexture(descriptor: descriptor)
        
        // Icon Texture
        iconTexture = device.makeTexture(descriptor: descriptor)
        
        // Bloom textures (half size)
        let bloomDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width/2, height: height/2, mipmapped: false)
        bloomDesc.usage = [.renderTarget, .shaderRead]
        bloomTexture1 = device.makeTexture(descriptor: bloomDesc)
        bloomTexture2 = device.makeTexture(descriptor: bloomDesc)
    }
    
    func resizeGrid(size: CGSize) {
        let newCols = max(1, Int(ceil(Float(size.width) / fontSize)))
        let newRows = max(1, Int(ceil(Float(size.height) / fontSize)))
        
        if newCols != cols || newRows != rows {
            cols = newCols
            rows = newRows
            
            if cols > 0 && rows > 0 {
                grid = Array(repeating: Array(repeating: 0, count: rows), count: cols)
                drops = Array(repeating: Drop(y: 0, speed: 0, tailLength: 0), count: cols)
                
                for c in 0..<cols {
                    for r in 0..<rows {
                        grid[c][r] = Int32.random(in: 0..<64)
                    }
                    resetDrop(col: c)
                    drops[c].y = Double.random(in: -Double(rows)...Double(rows))
                }
                
                let instanceCount = cols * rows
                instanceBuffer = device.makeBuffer(length: instanceCount * MemoryLayout<InstanceData>.stride, options: [.storageModeShared])
            }
        }
    }
    
    func resetDrop(col: Int) {
        drops[col].y = Double.random(in: -Double(rows)...0)
        drops[col].speed = Double.random(in: 10.0...30.0) // Restore original faster speed
        drops[col].tailLength = Double.random(in: 10...50) // Longer streams
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let scenePipelineState = scenePipelineState,
              let highPassPipelineState = highPassPipelineState,
              let blurPipelineState = blurPipelineState,
              let compositePipelineState = compositePipelineState,
              let textureAtlas = textureAtlas,
              let instanceBuffer = instanceBuffer,
              let sceneTexture = sceneTexture,
              let iconTexture = iconTexture,
              let bloomTexture1 = bloomTexture1,
              let bloomTexture2 = bloomTexture2 else { return }
        
        // Update Simulation
        let currentTime = CACurrentMediaTime()
        if lastTime == 0 { lastTime = currentTime }
        let deltaTime = min(currentTime - lastTime, 0.1)
        lastTime = currentTime
        
        updateSimulation(deltaTime: deltaTime)
        updateInstanceBuffer()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Pass 0: Render Icons to Texture
        if let iconRenderer = iconRenderer {
            iconRenderer.render(to: iconTexture, commandBuffer: commandBuffer)
        }
        
        // Pass 1: Render Scene to Texture
        let scenePass = MTLRenderPassDescriptor()
        scenePass.colorAttachments[0].texture = sceneTexture
        scenePass.colorAttachments[0].loadAction = .clear
        scenePass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        scenePass.colorAttachments[0].storeAction = .store
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: scenePass) {
            encoder.setRenderPipelineState(scenePipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
            
            var uniforms = Uniforms(viewportSize: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
                                    atlasDimensions: textureAtlas.atlasDimensions,
                                    glyphSize: SIMD2<Float>(fontSize, fontSize)) // Pass font size
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
            encoder.setFragmentTexture(textureAtlas.texture, index: 0)
            encoder.setFragmentTexture(iconTexture, index: 1) // Pass icon texture
            
            let instanceCount = cols * rows
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instanceCount)
            encoder.endEncoding()
        }
        
        // Pass 2: High Pass (Scene -> Bloom1)
        let highPassDesc = MTLRenderPassDescriptor()
        highPassDesc.colorAttachments[0].texture = bloomTexture1
        highPassDesc.colorAttachments[0].loadAction = .dontCare
        highPassDesc.colorAttachments[0].storeAction = .store
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: highPassDesc) {
            encoder.setRenderPipelineState(highPassPipelineState)
            encoder.setFragmentTexture(sceneTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
        
        // Pass 3: Blur Horizontal (Bloom1 -> Bloom2)
        let blurHDesc = MTLRenderPassDescriptor()
        blurHDesc.colorAttachments[0].texture = bloomTexture2
        blurHDesc.colorAttachments[0].loadAction = .dontCare
        blurHDesc.colorAttachments[0].storeAction = .store
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: blurHDesc) {
            encoder.setRenderPipelineState(blurPipelineState)
            encoder.setFragmentTexture(bloomTexture1, index: 0)
            var direction = SIMD2<Float>(1, 0)
            encoder.setFragmentBytes(&direction, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
        
        // Pass 4: Blur Vertical (Bloom2 -> Bloom1)
        let blurVDesc = MTLRenderPassDescriptor()
        blurVDesc.colorAttachments[0].texture = bloomTexture1
        blurVDesc.colorAttachments[0].loadAction = .dontCare
        blurVDesc.colorAttachments[0].storeAction = .store
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: blurVDesc) {
            encoder.setRenderPipelineState(blurPipelineState)
            encoder.setFragmentTexture(bloomTexture2, index: 0)
            var direction = SIMD2<Float>(0, 1)
            encoder.setFragmentBytes(&direction, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
        
        // Pass 5: Composite (Scene + Bloom1 -> Drawable)
        let compositeDesc = view.currentRenderPassDescriptor!
        // Ensure we load the existing content if we want transparency?
        // No, we clear to transparent in the view setup.
        // But here we are drawing a full screen quad.
        // The composite shader outputs (scene.rgb + bloom, scene.a).
        // So transparency is preserved.
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: compositeDesc) {
            encoder.setRenderPipelineState(compositePipelineState)
            encoder.setFragmentTexture(sceneTexture, index: 0)
            encoder.setFragmentTexture(bloomTexture1, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func updateSimulation(deltaTime: Double) {
        for c in 0..<cols {
            drops[c].y += drops[c].speed * deltaTime
            
            if drops[c].y - drops[c].tailLength > Double(rows) {
                resetDrop(col: c)
            }
            
            if Double.random(in: 0...1) < (0.5 * deltaTime) {
                let r = Int.random(in: 0..<rows)
                if r < grid[c].count {
                    grid[c][r] = Int32.random(in: 0..<64)
                }
            }
        }
    }
    
    func updateInstanceBuffer() {
        let pointer = instanceBuffer.contents().bindMemory(to: InstanceData.self, capacity: cols * rows)
        
        for c in 0..<cols {
            let dropY = drops[c].y
            let tailLength = drops[c].tailLength
            
            for r in 0..<rows {
                let index = c * rows + r
                
                let dist = dropY - Double(r)
                var brightness: Float = 0.0
                var isHead: Float = 0.0
                
                if dist >= 0 && dist < tailLength {
                    // Slower falloff (power < 1.0 keeps it brighter longer)
                    let normalizedDist = Float(dist / tailLength)
                    brightness = pow(1.0 - normalizedDist, 0.7)
                    
                    if dist < 1.0 { isHead = 1.0 }
                }
                
                let x = Float(c) * fontSize
                let y = Float(r) * fontSize
                
                pointer[index] = InstanceData(
                    position: SIMD2<Float>(x, y),
                    glyphIndex: grid[c][r],
                    brightness: brightness,
                    isHead: isHead,
                    padding: SIMD3<Float>(0,0,0)
                )
            }
        }
    }
}
