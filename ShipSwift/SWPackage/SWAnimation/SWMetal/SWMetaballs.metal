//
//  SWMetaballs.metal
//  ShipSwift
//
//  Stitchable SwiftUI color effect — glowing jelly metaball blobs.
//
//  Up to eight signed-distance circles orbit independently and are merged
//  via a polynomial smooth-min (Inigo Quilez) into a single fluid field.
//  The merged blob is shaded as a translucent jelly orb — every shading
//  cue is driven by the surface itself rather than baked into a flat
//  gradient, so the result feels three-dimensional from any angle:
//
//    1. Per-ball fake spherical normal blended by influence weight
//    2. Color triplet (highlight / mid / shadow) mixed by Lambertian term
//    3. Fresnel edge — pow(1 - n.z, k) — for translucent glass rim
//    4. Subsurface depth tint — interior darkens / saturates with depth
//    5. Specular hot spot from a single key light (`reflect()` + view)
//    6. Sub-orb caustic noise so the interior never looks frozen
//    7. Soft rim halo (glow) just outside the silhouette
//
//  Paired with: SWMetaballs.swift
//  Entry point: `swMetaballs` — invoked via SwiftUI `.colorEffect(...)`.
//
//  Requires iOS 17+ / macOS 14+.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Polynomial smooth-min — blends two SDFs by `k`. Higher k = gooier merge.
// Inigo Quilez: https://iquilezles.org/articles/smin/
static float swMetaballsSmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// 1D scalar hash for per-ball orbit parameters. Cheap and good-enough
// for static-per-frame ball identity.
static float swMetaballsHash(float n) {
    return fract(sin(n) * 43758.5453);
}

// Cheap value noise — used for sub-orb caustic shimmer.
static float swMetaballsValueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = swMetaballsHash(i.x + i.y * 57.0);
    float b = swMetaballsHash(i.x + 1.0 + i.y * 57.0);
    float c = swMetaballsHash(i.x + (i.y + 1.0) * 57.0);
    float d = swMetaballsHash(i.x + 1.0 + (i.y + 1.0) * 57.0);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

[[ stitchable ]] half4 swMetaballs(float2 position,
                                   half4  color,
                                   float4 boundingRect,
                                   float  time,
                                   float  speed,
                                   float  ballCount,
                                   float  ballSize,
                                   float  smoothness,
                                   float  edgeSoftness,
                                   float  lightingIntensity,
                                   float  rimHighlight,
                                   float  innerShadow,
                                   half4  colorHighlight,
                                   half4  colorMid,
                                   half4  colorShadow,
                                   half4  background) {
    float2 size = boundingRect.zw;
    float  minDim = max(min(size.x, size.y), 1.0);
    // Centered, aspect-preserving coords (-1..1 along short axis).
    float2 uv = (position - 0.5 * size) / minDim;

    float t = time * speed;

    int count = int(clamp(ballCount, 1.0, 8.0));

    // Initialize field to a "far positive" SDF so the first smin returns
    // the first ball cleanly.
    float field = 10.0;

    // Accumulators for per-ball spherical normal blending.
    // Each ball contributes a hemisphere normal weighted by how strongly
    // it influences the current pixel; the merge stays smooth across
    // ball boundaries because the weight tapers, not the normal itself.
    float3 accumNormal = float3(0.0);
    float  accumWeight = 0.0;

    // Loop bound is the static `8` so the compiler can unroll.
    for (int i = 0; i < 8; i++) {
        if (i >= count) break;
        float fi = float(i);
        // Each ball has its own orbit radius, angular speed, and phase.
        float orbitR     = mix(0.15, 0.45, swMetaballsHash(fi + 1.7));
        float orbitSpeed = mix(0.3,  1.1,  swMetaballsHash(fi + 5.3));
        float phase      = swMetaballsHash(fi + 9.1) * 6.2831;
        float2 c = orbitR * float2(cos(t * orbitSpeed + phase),
                                    sin(t * orbitSpeed * 0.83 + phase));
        float r = ballSize * mix(0.6, 1.2, swMetaballsHash(fi + 11.7));
        float2 toCenter = uv - c;
        float  dCenter = length(toCenter);
        float  d = dCenter - r;
        field = swMetaballsSmin(field, d, max(smoothness, 0.0001));

        // Fake hemisphere normal — `nz = sqrt(1 - planar²)` recovers the
        // missing depth so we can treat the disc as a 3D dome. Cubic
        // falloff makes the closest ball dominate cleanly.
        float reach = r * 1.4;
        float inside = saturate(1.0 - dCenter / max(reach, 0.0001));
        float w = inside * inside * inside;
        if (w > 0.0001) {
            float nx = toCenter.x / max(r, 0.0001);
            float ny = toCenter.y / max(r, 0.0001);
            float planar = nx * nx + ny * ny;
            float nz = sqrt(max(0.0, 1.0 - min(planar, 1.0)));
            float3 n = normalize(float3(nx, ny, nz + 0.001));
            accumNormal += n * w;
            accumWeight += w;
        }
    }

    // Soft alpha mask — used to composite shaded jelly over the bg.
    float es = max(edgeSoftness, 0.0001);
    float mask = 1.0 - smoothstep(0.0, es, field);

    // ── Surface frame ──────────────────────────────────────────────
    float3 normal = accumWeight > 0.0
        ? normalize(accumNormal / accumWeight)
        : float3(0.0, 0.0, 1.0);
    float3 viewDir = float3(0.0, 0.0, 1.0);

    // Key light slightly above and to the right; cool fill from below.
    float3 keyLight  = normalize(float3( 0.35, -0.65,  0.75));
    float3 fillLight = normalize(float3(-0.25,  0.55,  0.55));

    float keyTerm  = saturate(dot(normal, keyLight));
    float fillTerm = saturate(dot(normal, fillLight)) * 0.45;

    // ── Layer A: triplet shading driven by lighting term ───────────
    // grad ∈ [0, 1] from shadow → mid → highlight as the light grows.
    float grad = saturate(keyTerm + fillTerm * 0.6);
    float3 baseColor = grad < 0.5
        ? mix(float3(colorShadow.rgb), float3(colorMid.rgb),       grad * 2.0)
        : mix(float3(colorMid.rgb),    float3(colorHighlight.rgb), (grad - 0.5) * 2.0);

    // Lighting intensity controls how much the triplet leans on the
    // lambertian term vs. a flat mid tone — useful for matte vs. waxy.
    float3 flatTone = float3(colorMid.rgb);
    baseColor = mix(flatTone, baseColor, saturate(lightingIntensity));

    // ── Layer B: subsurface depth tint ─────────────────────────────
    // Inside the merged blob `field` is negative; clamp the depth band
    // by ballSize so larger blobs stay readable.
    float depthBand = max(ballSize * 0.9, 0.04);
    float depth = saturate(-field / depthBand);
    // Smooth so the rolloff feels organic rather than linear.
    float depthCurve = smoothstep(0.0, 1.0, depth);
    // Edges desaturate / darken toward shadow color; deep cores stay rich.
    float3 sssColor = mix(float3(colorShadow.rgb) * 0.55, baseColor, depthCurve);
    float darkenBase = mix(1.0, 1.0 - saturate(innerShadow), 1.0 - depthCurve);
    baseColor = sssColor * darkenBase;

    // ── Layer C: caustic shimmer (sub-orb interior light) ─────────
    // Low-frequency noise modulated by depth, so it only shows up where
    // there *is* material to scatter light through.
    float caustic = swMetaballsValueNoise(uv * 5.5 + float2(t * 0.35, -t * 0.27));
    caustic = (caustic - 0.5) * 0.18 * depthCurve;
    baseColor += baseColor * caustic;

    // ── Layer D: specular hot spot ────────────────────────────────
    float3 reflKey = reflect(-keyLight, normal);
    float  spec = pow(saturate(dot(reflKey, viewDir)), 28.0);
    // Specular intensity scales with the rim setting — "wetter" + glassier
    // when the user wants more rim, drier when they don't.
    float specGain = mix(0.25, 0.85, saturate(rimHighlight));
    baseColor += float3(1.0) * spec * specGain;

    // ── Layer E: fresnel edge (translucent glass rim) ─────────────
    // Edge of the dome where the normal grazes the camera direction.
    float fresnel = pow(1.0 - saturate(normal.z), 3.0);
    float fresnelGain = saturate(rimHighlight) * 0.85;
    baseColor = mix(baseColor, float3(1.0), fresnel * fresnelGain);

    // ── Composite over background using the SDF mask ──────────────
    float3 col = mix(float3(background.rgb), baseColor, mask);

    // ── Layer F: soft halo just outside the silhouette ────────────
    // Tints the immediate exterior with the highlight color so the orb
    // looks like it's emitting light, not stamped onto the background.
    // Uses a wider falloff than the mask so it reads as a glow band.
    float halo = (1.0 - smoothstep(0.0, es * 6.0, field)) * (1.0 - mask);
    float haloGain = saturate(rimHighlight) * 0.35;
    col += float3(colorHighlight.rgb) * halo * haloGain;

    return half4(half3(col), 1.0);
}
