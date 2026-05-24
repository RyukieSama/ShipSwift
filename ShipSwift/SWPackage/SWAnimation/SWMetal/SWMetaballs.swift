//
//  SWMetaballs.swift
//  ShipSwift
//
//  Gooey metaball blobs rendered via a SwiftUI Metal stitchable shader,
//  shaded as glowing translucent jelly orbs — every shading cue is driven
//  by the surface itself rather than baked into a flat gradient:
//
//    • Per-ball fake spherical normal blended by influence weight
//    • Triplet colors mixed by Lambertian term (highlight / mid / shadow)
//    • Fresnel edge for a translucent glass rim
//    • Subsurface depth tint — interior darkens / saturates with depth
//    • Specular hot spot from a key light
//    • Sub-orb caustic shimmer so the interior never freezes
//    • Soft external halo so the orb looks emissive
//
//  Requires iOS 17+ / macOS 14+ (SwiftUI `ShaderLibrary`,
//  `Shader`/`ShaderFunction`, Metal `stitchable`).
//
//  Usage:
//    // Default — violet → cyan → lime jelly orbs, full-screen
//    ZStack {
//        SWMetaballs()
//            .ignoresSafeArea()
//        // Your content here
//    }
//
//    // Recolor — molten lava
//    SWMetaballs(
//        color1: .yellow,          // highlight (lit face)
//        color2: .orange,          // mid       (side)
//        color3: .red,             // shadow    (back face)
//        background: .black
//    )
//
//    // As a section background
//    myContent
//        .background { SWMetaballs() }
//
//    // Demo / debug — adds a gear button in the navigation bar that
//    // opens a sheet to tweak every parameter live. Disabled by default.
//    SWMetaballs(showsControls: true)
//
//  Parameters:
//    - color1: Highlight color, painted where the surface faces the key
//              light (default violet `#6633FF`)
//    - color2: Mid tone, painted on grazing / side-lit areas
//              (default cyan `#56CDE3`)
//    - color3: Shadow color, painted on back-lit / deep interior regions
//              (default lime `#C7F648`)
//    - background: Color rendered behind the blobs
//                  (default near-black `#0A0612`)
//    - speed: Multiplier on the internal orbit time (default `1.0`)
//    - ballCount: Number of metaballs, clamped to 1–8 (default `5`)
//    - ballSize: Base radius of each ball in normalized short-axis units
//                (default `0.18`)
//    - smoothness: Smooth-min blend factor — higher = gooier merge
//                  (default `0.15`)
//    - edgeSoftness: Width of the SDF → alpha smoothstep — higher =
//                    softer halo around the merged field (default `0.02`)
//    - lightingIntensity: How strongly shading leans on the lambertian
//                         triplet vs. a flat mid tone — 0 = matte flat,
//                         1 = waxy directional (default `0.85`)
//    - rimHighlight: Combined gain for the fresnel rim, specular hot
//                    spot, and external halo — 0 = none, 1 = glassy /
//                    luminous (default `0.6`)
//    - innerShadow: Depth-driven edge darkening inside the blob — 0 =
//                   uniform, 1 = deep pillow (default `0.45`)
//    - showsControls: When `true`, adds a gear `ToolbarItem` to the
//                     enclosing `NavigationStack` that opens a
//                     live-tuning sheet. Default `false`.
//
//  Notes:
//    - The shader's loop bound is the static `8` so it always unrolls;
//      values above 8 are silently truncated.
//    - Each ball's orbit (radius / speed / phase / size jitter) is
//      derived from a deterministic hash of its index, so the cluster
//      animates consistently across frames.
//    - When `showsControls` is `true`, the gear button is a native
//      `ToolbarItem` — the call site must be inside a `NavigationStack`.
//
//  Created by Wei Zhong on 5/24/26.
//

import SwiftUI

// MARK: - Main View

struct SWMetaballs: View {
    /// Highlight color — painted where the surface faces the key light.
    var color1: Color = Color(red: 0.4,   green: 0.2,   blue: 1.0)    // #6633FF

    /// Mid tone — painted on grazing / side-lit areas.
    var color2: Color = Color(red: 0.337, green: 0.804, blue: 0.890)  // #56CDE3

    /// Shadow color — painted on back-lit / deep interior regions.
    var color3: Color = Color(red: 0.780, green: 0.965, blue: 0.282)  // #C7F648

    /// Color rendered behind the blobs.
    var background: Color = Color(red: 0.039, green: 0.024, blue: 0.071) // #0A0612

    /// Multiplier on the internal orbit time.
    var speed: Float = 1.0

    /// Number of metaballs (clamped to 1–8 by the shader).
    var ballCount: Int = 5

    /// Base radius of each ball in normalized short-axis units.
    var ballSize: Float = 0.18

    /// Smooth-min blend factor — higher = gooier merge.
    var smoothness: Float = 0.15

    /// Width of the SDF → alpha smoothstep — higher = softer halo.
    var edgeSoftness: Float = 0.02

    /// Lambertian shading weight (0 = flat mid tone, 1 = full triplet shading).
    var lightingIntensity: Float = 0.85

    /// Combined gain for fresnel rim, specular hot spot, and external halo
    /// (0 = matte, 1 = glassy / luminous).
    var rimHighlight: Float = 0.6

    /// Depth-driven edge darkening inside the blob (0 = uniform, 1 = deep pillow).
    var innerShadow: Float = 0.45

    /// When `true`, attaches a gear `ToolbarItem` that opens a live-tuning sheet.
    var showsControls: Bool = false

    var body: some View {
        if showsControls {
            SWMetaballsControlled(initial: self)
        } else {
            SWMetaballsRenderer(
                color1: color1,
                color2: color2,
                color3: color3,
                background: background,
                speed: speed,
                ballCount: ballCount,
                ballSize: ballSize,
                smoothness: smoothness,
                edgeSoftness: edgeSoftness,
                lightingIntensity: lightingIntensity,
                rimHighlight: rimHighlight,
                innerShadow: innerShadow
            )
        }
    }
}

// MARK: - Renderer (pure shader binding)

private struct SWMetaballsRenderer: View {
    let color1: Color
    let color2: Color
    let color3: Color
    let background: Color
    let speed: Float
    let ballCount: Int
    let ballSize: Float
    let smoothness: Float
    let edgeSoftness: Float
    let lightingIntensity: Float
    let rimHighlight: Float
    let innerShadow: Float

    @State private var start: Date = .now

    var body: some View {
        TimelineView(.animation) { ctx in
            let elapsed = Float(ctx.date.timeIntervalSince(start))
            // The base layer is `background` — the shader overwrites every
            // pixel, but this keeps the first frame visually correct before
            // TimelineView begins ticking.
            background
                .colorEffect(
                    ShaderLibrary.swMetaballs(
                        .boundingRect,
                        .float(elapsed),
                        .float(speed),
                        .float(Float(ballCount)),
                        .float(ballSize),
                        .float(smoothness),
                        .float(edgeSoftness),
                        .float(lightingIntensity),
                        .float(rimHighlight),
                        .float(innerShadow),
                        .color(color1),
                        .color(color2),
                        .color(color3),
                        .color(background)
                    )
                )
        }
    }
}

// MARK: - Controlled Wrapper (gear toolbar item + live sheet)

private struct SWMetaballsControlled: View {
    @State private var color1: Color
    @State private var color2: Color
    @State private var color3: Color
    @State private var background: Color
    @State private var speed: Float
    /// Float-backed so it can drive a Slider; rendered as `Int(.rounded())`.
    @State private var ballCount: Float
    @State private var ballSize: Float
    @State private var smoothness: Float
    @State private var edgeSoftness: Float
    @State private var lightingIntensity: Float
    @State private var rimHighlight: Float
    @State private var innerShadow: Float

    @State private var showSheet = false

    init(initial: SWMetaballs) {
        _color1            = State(initialValue: initial.color1)
        _color2            = State(initialValue: initial.color2)
        _color3            = State(initialValue: initial.color3)
        _background        = State(initialValue: initial.background)
        _speed             = State(initialValue: initial.speed)
        _ballCount         = State(initialValue: Float(initial.ballCount))
        _ballSize          = State(initialValue: initial.ballSize)
        _smoothness        = State(initialValue: initial.smoothness)
        _edgeSoftness      = State(initialValue: initial.edgeSoftness)
        _lightingIntensity = State(initialValue: initial.lightingIntensity)
        _rimHighlight      = State(initialValue: initial.rimHighlight)
        _innerShadow       = State(initialValue: initial.innerShadow)
    }

    var body: some View {
        SWMetaballsRenderer(
            color1: color1,
            color2: color2,
            color3: color3,
            background: background,
            speed: speed,
            ballCount: Int(ballCount.rounded()),
            ballSize: ballSize,
            smoothness: smoothness,
            edgeSoftness: edgeSoftness,
            lightingIntensity: lightingIntensity,
            rimHighlight: rimHighlight,
            innerShadow: innerShadow
        )
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Metaballs Controls")
            }
        }
        .sheet(isPresented: $showSheet) {
            SWMetaballsControlsSheet(
                color1: $color1,
                color2: $color2,
                color3: $color3,
                background: $background,
                speed: $speed,
                ballCount: $ballCount,
                ballSize: $ballSize,
                smoothness: $smoothness,
                edgeSoftness: $edgeSoftness,
                lightingIntensity: $lightingIntensity,
                rimHighlight: $rimHighlight,
                innerShadow: $innerShadow
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Controls Sheet

private struct SWMetaballsControlsSheet: View {
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var color3: Color
    @Binding var background: Color
    @Binding var speed: Float
    @Binding var ballCount: Float
    @Binding var ballSize: Float
    @Binding var smoothness: Float
    @Binding var edgeSoftness: Float
    @Binding var lightingIntensity: Float
    @Binding var rimHighlight: Float
    @Binding var innerShadow: Float

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Colors") {
                    ColorPicker("Color 1 (highlight)", selection: $color1,     supportsOpacity: false)
                    ColorPicker("Color 2 (mid)",       selection: $color2,     supportsOpacity: false)
                    ColorPicker("Color 3 (shadow)",    selection: $color3,     supportsOpacity: false)
                    ColorPicker("Background",          selection: $background, supportsOpacity: false)
                }

                Section("Field") {
                    SliderRow(label: "Ball Count",    value: $ballCount,    range: 1...8,      step: 1)
                    SliderRow(label: "Ball Size",     value: $ballSize,     range: 0.05...0.5, step: 0.01)
                    SliderRow(label: "Smoothness",    value: $smoothness,   range: 0.01...0.5, step: 0.01)
                    SliderRow(label: "Edge Softness", value: $edgeSoftness, range: 0.001...0.2, step: 0.001)
                }

                Section("Shading") {
                    SliderRow(label: "Lighting",     value: $lightingIntensity, range: 0...1, step: 0.01)
                    SliderRow(label: "Rim Highlight", value: $rimHighlight,      range: 0...1, step: 0.01)
                    SliderRow(label: "Inner Shadow", value: $innerShadow,       range: 0...1, step: 0.01)
                }

                Section("Motion") {
                    SliderRow(label: "Speed", value: $speed, range: 0...3, step: 0.05)
                }
            }
            .navigationTitle("Metaballs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(formattedValue)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }

    /// Integer-stepped sliders look cleaner as whole numbers.
    private var formattedValue: String {
        step >= 1
            ? "\(Int(value.rounded()))"
            : String(format: "%.3f", value)
    }
}

// MARK: - Preview

#Preview("Aurora (default)") {
    // ToolbarItem requires an enclosing NavigationStack to render.
    NavigationStack {
        SWMetaballs(showsControls: true)
    }
}

#Preview("Lava") {
    SWMetaballs(
        color1: Color(red: 1.0, green: 0.85, blue: 0.2),
        color2: Color(red: 1.0, green: 0.35, blue: 0.05),
        color3: Color(red: 0.45, green: 0.05, blue: 0.05),
        background: .black
    )
    .ignoresSafeArea()
}

#Preview("Ocean") {
    SWMetaballs(
        color1: Color(red: 0.55, green: 0.85, blue: 1.0),
        color2: Color(red: 0.15, green: 0.45, blue: 0.85),
        color3: Color(red: 0.05, green: 0.1,  blue: 0.35),
        background: Color(red: 0.02, green: 0.03, blue: 0.08)
    )
    .ignoresSafeArea()
}
