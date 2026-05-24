//
//  SWHalftone.metal
//  ShipSwift
//
//  Stitchable SwiftUI color effect — print-shop halftone dots over a
//  procedurally generated luminance field.
//
//  A rotating radial gradient (drifting bright spot + low-frequency sin
//  band) provides the underlying luminance. The screen is then quantized
//  into a rotated cell grid; in each cell, one solid ink dot is drawn
//  with radius proportional to `(1 - luminance)` — dark cells get big
//  dots, bright cells get small or empty dots, producing the classic
//  newspaper-print "Lichtenstein" texture.
//
//  Paired with: SWHalftone.swift
//  Entry point: `swHalftone` — invoked via SwiftUI `.colorEffect(...)`.
//
//  Requires iOS 17+ / macOS 14+.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 swHalftone(float2 position,
                                  half4  color,
                                  float4 boundingRect,
                                  float  time,
                                  float  speed,
                                  float  dotSize,
                                  float  angle,
                                  float  scale,
                                  float  contrast,
                                  half4  ink,
                                  half4  paper) {
    float2 size   = boundingRect.zw;
    float2 center = 0.5 * size;
    float  minDim = max(min(size.x, size.y), 1.0);

    float t = time * speed;

    // Rotate the pixel position into the halftone grid space. Real CMYK
    // plates are angled (15°, 45°, 75°) to avoid moire — exposing `angle`
    // lets the user dial that in.
    float s = sin(angle);
    float c = cos(angle);
    float2 p       = position - center;
    float2 rotated = float2(c * p.x - s * p.y,
                            s * p.x + c * p.y);

    // Quantize rotated position to a cell. One dot per cell, all dots in
    // a cell evaluated against the same per-cell luminance.
    float  cellSize         = max(dotSize, 1.0);
    float2 cellIndex        = floor(rotated / cellSize);
    float2 rotatedCellCenter = (cellIndex + 0.5) * cellSize;

    // Inverse-rotate the cell center back to screen space so luminance
    // (which is defined in the unrotated source frame) is sampled at the
    // visual position of the dot, not at the rotated grid coordinate.
    float2 cellPxOffset = float2( c * rotatedCellCenter.x + s * rotatedCellCenter.y,
                                  -s * rotatedCellCenter.x + c * rotatedCellCenter.y);
    float2 cellPxCenter = cellPxOffset + center;

    // Procedural luminance — a bright spot wobbling around the center +
    // a horizontal sin band for variety. Output is in [0, 1] after the
    // contrast shape.
    float2 cellUV = (cellPxCenter - center) / minDim;
    float2 wob    = 0.4 * float2(cos(t * 0.6), sin(t * 0.8));
    float  lum    = 1.0 - length(cellUV - wob) * 1.4;
    lum          += 0.3 * sin(cellUV.y * 5.0 * max(scale, 0.0001) + t * 1.4);
    lum           = clamp((lum - 0.5) * max(contrast, 0.0001) + 0.5, 0.0, 1.0);

    // Dot radius: dark cells (low lum) draw a large dot. Factor 1.414
    // (≈ √2) lets dots overlap into solid ink at full black.
    float maxR = cellSize * 0.5 * 1.414;
    float r    = (1.0 - lum) * maxR;

    // Distance from current rotated pixel to its rotated cell center.
    // Smoothstep edge in screen-pixel units (0.7) gives anti-aliased dot rims
    // regardless of cell size.
    float dist = length(rotated - rotatedCellCenter);
    float mask = 1.0 - smoothstep(r - 0.7, r + 0.7, dist);

    half3 col = mix(paper.rgb, ink.rgb, half(mask));
    return half4(col, 1.0);
}
