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
};

struct InstanceData {
    float2 position; // Top-left position in pixels
    int glyphIndex;  // Index in the atlas
    float brightness;
    float isHead;    // 0.0 or 1.0
    float3 padding;  // Pad to 32 bytes (8+4+4+4 = 20, +12 = 32)
};

struct Uniforms {
    float2 viewportSize;
    float2 atlasDimensions;
    float2 glyphSize; // Added
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
    // 0,0 is top-left in screen, but -1,1 is top-left in clip
    float2 clipPos = (pixelPos / uniforms.viewportSize) * 2.0 - 1.0;
    clipPos.y = -clipPos.y; // Flip Y
    
    out.position = float4(clipPos, 0.0, 1.0);
    
    // Calculate Texture Coordinates
    // Atlas is a grid.
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
                               sampler textureSampler [[sampler(0)]]) {
    
    float4 sample = atlasTexture.sample(textureSampler, in.texCoord);
    // Use red channel as alpha to support both transparent and black backgrounds
    float alpha = sample.r;
    
    if (alpha < 0.1) discard_fragment();
    
    float3 color;
    
    // Color Palette Simulation
    if (in.isHead) {
        // Head is white with a slight green tint
        color = float3(0.8, 1.0, 0.8);
        // Boost brightness for glow effect
        color *= 2.0; // Increased boost
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

// Post-Processing Shaders

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
