#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]]; // Unit quad position (0,0 to 1,1)
    float2 texCoord [[attribute(1)]]; // UVs (0,0 to 1,1)
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float brightness;
    bool isHead;
    float2 screenUV; // Added for icon map sampling
};

struct InstanceData {
    float2 position; // Top-left position in pixels
    int glyphIndex;  // Index in the atlas
    float brightness;
    float isHead;    // 0.0 or 1.0
    float3 padding;  // Pad to 32 bytes
};

struct Uniforms {
    float2 viewportSize;
    float2 atlasDimensions;
    float2 glyphSize;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                              constant InstanceData* instances [[buffer(1)]],
                              constant Uniforms& uniforms [[buffer(2)]],
                              uint instanceID [[instance_id]]) {
    VertexOut out;
    InstanceData instance = instances[instanceID];
    
    // Use uniform glyph size to match renderer
    float2 pixelPos = instance.position + in.position * uniforms.glyphSize;
    
    // Convert to clip space (-1 to 1)
    float2 clipPos = (pixelPos / uniforms.viewportSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y; // Flip Y
    
    out.position = float4(clipPos, 0.0, 1.0);
    out.screenUV = pixelPos / uniforms.viewportSize; // Pass screen UV
    
    // Calculate Texture Coordinates
    int cols = int(uniforms.atlasDimensions.x);
    int row = instance.glyphIndex / cols;
    int col = instance.glyphIndex % cols;
    
    float2 uvPerGlyph = 1.0 / uniforms.atlasDimensions;
    float2 uvOffset = float2(float(col), float(row)) * uvPerGlyph;
    
    out.texCoord = uvOffset + in.texCoord * uvPerGlyph;
    
    out.brightness = instance.brightness;
    out.isHead = (instance.isHead > 0.5);
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> atlasTexture [[texture(0)]],
                               texture2d<float> iconTexture [[texture(1)]], // Added icon map
                               sampler textureSampler [[sampler(0)]]) {
    
    float4 sample = atlasTexture.sample(textureSampler, in.texCoord);
    float alpha = sample.r;
    
    if (alpha < 0.1) discard_fragment();
    
    // Sample icon map
    constexpr sampler iconSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 iconColor = iconTexture.sample(iconSampler, in.screenUV);
    float iconBrightness = iconColor.r; // Grayscale value
    
    float3 color;
    
    // Color Palette Simulation
    if (in.isHead) {
        // Head is white with a slight green tint
        color = float3(0.8, 1.0, 0.8);
        
        // Modulate brightness with icon map
        // Boost brightness where icon is present
        if (iconBrightness > 0.1) {
             color += float3(iconBrightness * 2.0); // Add icon brightness
        }
        
        color *= 2.0; // Base boost
    } else {
        // Tail
        float3 baseGreen = float3(0.0, 0.9, 0.2);
        float3 darkGreen = float3(0.0, 0.2, 0.05);
        
        color = mix(darkGreen, baseGreen, in.brightness);
    }
    
    // Apply brightness falloff
    color *= in.brightness;
    
    return float4(color, alpha * in.brightness);
}

// ... Post-Processing Shaders ...

// Icon Rendering Shaders

struct IconVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex IconVertexOut iconVertexShader(uint vertexID [[vertex_id]],
                                      constant float4& rect [[buffer(0)]], // x, y, w, h
                                      constant float2& viewport [[buffer(1)]]) {
    IconVertexOut out;
    
    // 0, 1, 2, 3 -> Triangle Strip
    float2 positions[4] = {
        float2(0, 0),
        float2(1, 0),
        float2(0, 1),
        float2(1, 1)
    };
    
    // UVs for upright image (0,0 bottom-left in Metal texture)
    // If texture loaded with origin bottom-left:
    // Top-Left vertex (0,0 relative) -> UV (0, 1)
    // Bottom-Left vertex (0,1 relative) -> UV (0, 0)
    // Wait, rect.y is top or bottom?
    // In IconRenderer: y = (height - h) / 2. This is top-down Y?
    // If viewport (0,0) is top-left.
    // Then rect.y is distance from top.
    // Vertex 0 (0,0) -> rect.x, rect.y (Top-Left)
    // Vertex 2 (0,1) -> rect.x, rect.y + h (Bottom-Left)
    
    float2 texCoords[4] = {
        float2(0, 1), // Top-Left
        float2(1, 1), // Top-Right
        float2(0, 0), // Bottom-Left
        float2(1, 0)  // Bottom-Right
    };
    
    float2 pos = positions[vertexID];
    float2 pixelPos = rect.xy + pos * rect.zw;
    
    // Convert to clip space
    // 0,0 top-left -> -1, 1
    float2 clipPos = (pixelPos / viewport) * 2.0 - 1.0;
    clipPos.y = -clipPos.y; // Flip Y
    
    out.position = float4(clipPos, 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    
    return out;
}

fragment float4 iconFragmentShader(IconVertexOut in [[stage_in]],
                                   texture2d<float> iconTex [[texture(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 color = iconTex.sample(s, in.texCoord);
    
    // Convert to grayscale for height map
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    // Output luminance in all channels, preserve alpha
    return float4(luminance, luminance, luminance, color.a);
}

// ... Existing Post-Processing Shaders ...
struct QuadVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex QuadVertexOut quadVertexShader(uint vertexID [[vertex_id]]) {
    QuadVertexOut out;
    // Full screen quad triangle strip: (-1, -1), (1, -1), (-1, 1), (1, 1)
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    
    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 highPassShader(QuadVertexOut in [[stage_in]],
                               texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 color = tex.sample(s, in.texCoord);
    
    // Threshold
    float threshold = 0.2; // Lower threshold for more bloom
    float3 brightColor = max(color.rgb - threshold, 0.0);
    
    return float4(brightColor, color.a);
}

fragment float4 blurShader(QuadVertexOut in [[stage_in]],
                           texture2d<float> tex [[texture(0)]],
                           constant float2& direction [[buffer(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    
    // 5-tap Gaussian blur
    float2 size = float2(tex.get_width(), tex.get_height());
    float2 off1 = float2(1.3846153846) * direction / size;
    float2 off2 = float2(3.2307692308) * direction / size;
    
    float4 color = tex.sample(s, in.texCoord) * 0.227027;
    color += tex.sample(s, in.texCoord + off1) * 0.3162162;
    color += tex.sample(s, in.texCoord - off1) * 0.3162162;
    color += tex.sample(s, in.texCoord + off2) * 0.0702702;
    color += tex.sample(s, in.texCoord - off2) * 0.0702702;
    
    return color;
}

fragment float4 compositeShader(QuadVertexOut in [[stage_in]],
                                texture2d<float> sceneTex [[texture(0)]],
                                texture2d<float> bloomTex [[texture(1)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    
    float4 scene = sceneTex.sample(s, in.texCoord);
    float4 bloom = bloomTex.sample(s, in.texCoord);
    
    // Additive blending
    float3 finalColor = scene.rgb + bloom.rgb * 3.0; // Boost bloom even more
    
    return float4(finalColor, scene.a);
}
