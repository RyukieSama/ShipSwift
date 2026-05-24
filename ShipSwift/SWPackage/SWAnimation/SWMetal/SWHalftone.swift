//
//  SWHalftone.swift
//  ShipSwift
//
//  Print-shop halftone dots over a procedurally drifting luminance field,
//  rendered via a SwiftUI Metal stitchable shader. The screen is quantized
//  into a rotated cell grid; each cell draws one ink dot whose radius is
//  proportional to `(1 - luminance)` — dark = big dot, bright = small or
//  empty. Output reads like a newspaper-print / Lichtenstein texture.
//
//  Requires iOS 17+ / macOS 14+ (SwiftUI `ShaderLibrary`,
//  `Shader`/`ShaderFunction`, Metal `stitchable`).
//
//  Usage:
//    // Default — black ink on cream paper, full-screen
//    ZStack {
//        SWHalftone()
//            .ignoresSafeArea()
//        // Your content here
//    }
//
//    // Recolor — magenta on white, larger dots
//    SWHalftone(
//        dotSize: 24,
//        ink: .pink,
//        paper: .white
//    )
//
//    // As a section background
//    myContent
//        .background { SWHalftone() }
//
//    // Demo / debug — adds a gear button in the navigation bar that
//    // opens a sheet to tweak every parameter live. Disabled by default.
//    SWHalftone(showsControls: true)
//
//  Parameters:
//    - ink: Color of the dots (default near-black `#1A1A1A`)
//    - paper: Color of the background paper
//             (default warm cream `#F5EFE0`)
//    - speed: Multiplier on the internal luminance-spot drift time
//             (default `1.0`)
//    - dotSize: Cell size in screen pixels — also the maximum dot
//               diameter. Higher = chunkier print look (default `16`)
//    - angle: Grid rotation angle in radians. Real CMYK plates use
//             ~15° / 45° / 75° to avoid moire (default `0.785`, π/4)
//    - scale: Frequency of the horizontal sin band in the luminance
//             field — higher = more bands (default `1.0`)
//    - contrast: Steepness of the luminance → dot-size mapping —
//                higher = more pure black/white, lower = more midtones
//                (default `1.6`)
//    - showsControls: When `true`, adds a gear `ToolbarItem` to the
//                     enclosing `NavigationStack` that opens a
//                     live-tuning sheet. Default `false`.
//
//  Notes:
//    - This is a procedural full-screen background; it does NOT apply a
//      halftone filter to existing content. (That would be a `layerEffect`
//      and is intentionally not in scope for the current SWMetal family.)
//    - Dot edges are smoothstepped in screen-pixel units (±0.7) so they
//      stay anti-aliased at any `dotSize`.
//    - When `showsControls` is `true`, the gear button is a native
//      `ToolbarItem` — the call site must be inside a `NavigationStack`.
//
//  Created by Wei Zhong on 5/24/26.
//

import SwiftUI

// MARK: - Main View

struct SWHalftone: View {
    /// Color of the dots.
    var ink: Color = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A

    /// Color of the background paper.
    var paper: Color = Color(red: 0.961, green: 0.937, blue: 0.878) // #F5EFE0

    /// Multiplier on the internal luminance-spot drift time.
    var speed: Float = 1.0

    /// Cell size in screen pixels.
    var dotSize: Float = 16

    /// Grid rotation angle in radians (π/4 ≈ 0.785 by default).
    var angle: Float = 0.785

    /// Frequency of the horizontal sin band in the luminance field.
    var scale: Float = 1.0

    /// Steepness of the luminance → dot-size mapping.
    var contrast: Float = 1.6

    /// When `true`, attaches a gear `ToolbarItem` that opens a live-tuning sheet.
    var showsControls: Bool = false

    var body: some View {
        if showsControls {
            SWHalftoneControlled(initial: self)
        } else {
            SWHalftoneRenderer(
                ink: ink,
                paper: paper,
                speed: speed,
                dotSize: dotSize,
                angle: angle,
                scale: scale,
                contrast: contrast
            )
        }
    }
}

// MARK: - Renderer (pure shader binding)

private struct SWHalftoneRenderer: View {
    let ink: Color
    let paper: Color
    let speed: Float
    let dotSize: Float
    let angle: Float
    let scale: Float
    let contrast: Float

    @State private var start: Date = .now

    var body: some View {
        TimelineView(.animation) { ctx in
            let elapsed = Float(ctx.date.timeIntervalSince(start))
            // Base layer is `paper` so the first frame already looks correct
            // before the shader fills in the dots.
            paper
                .colorEffect(
                    ShaderLibrary.swHalftone(
                        .boundingRect,
                        .float(elapsed),
                        .float(speed),
                        .float(dotSize),
                        .float(angle),
                        .float(scale),
                        .float(contrast),
                        .color(ink),
                        .color(paper)
                    )
                )
        }
    }
}

// MARK: - Controlled Wrapper (gear toolbar item + live sheet)

private struct SWHalftoneControlled: View {
    @State private var ink: Color
    @State private var paper: Color
    @State private var speed: Float
    @State private var dotSize: Float
    @State private var angle: Float
    @State private var scale: Float
    @State private var contrast: Float

    @State private var showSheet = false

    init(initial: SWHalftone) {
        _ink      = State(initialValue: initial.ink)
        _paper    = State(initialValue: initial.paper)
        _speed    = State(initialValue: initial.speed)
        _dotSize  = State(initialValue: initial.dotSize)
        _angle    = State(initialValue: initial.angle)
        _scale    = State(initialValue: initial.scale)
        _contrast = State(initialValue: initial.contrast)
    }

    var body: some View {
        SWHalftoneRenderer(
            ink: ink,
            paper: paper,
            speed: speed,
            dotSize: dotSize,
            angle: angle,
            scale: scale,
            contrast: contrast
        )
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Halftone Controls")
            }
        }
        .sheet(isPresented: $showSheet) {
            SWHalftoneControlsSheet(
                ink: $ink,
                paper: $paper,
                speed: $speed,
                dotSize: $dotSize,
                angle: $angle,
                scale: $scale,
                contrast: $contrast
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Controls Sheet

private struct SWHalftoneControlsSheet: View {
    @Binding var ink: Color
    @Binding var paper: Color
    @Binding var speed: Float
    @Binding var dotSize: Float
    @Binding var angle: Float
    @Binding var scale: Float
    @Binding var contrast: Float

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Colors") {
                    ColorPicker("Ink",   selection: $ink,   supportsOpacity: false)
                    ColorPicker("Paper", selection: $paper, supportsOpacity: false)
                }

                Section("Grid") {
                    SliderRow(label: "Dot Size",  value: $dotSize,  range: 4...60,   step: 1)
                    SliderRow(label: "Angle",     value: $angle,    range: 0...1.57, step: 0.01)
                    SliderRow(label: "Scale",     value: $scale,    range: 0.1...5,  step: 0.05)
                    SliderRow(label: "Contrast",  value: $contrast, range: 0.2...5,  step: 0.05)
                }

                Section("Motion") {
                    SliderRow(label: "Speed", value: $speed, range: 0...3, step: 0.05)
                }
            }
            .navigationTitle("Halftone")
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
            : String(format: "%.2f", value)
    }
}

// MARK: - Preview

#Preview {
    // ToolbarItem requires an enclosing NavigationStack to render.
    NavigationStack {
        SWHalftone(showsControls: true)
    }
}
