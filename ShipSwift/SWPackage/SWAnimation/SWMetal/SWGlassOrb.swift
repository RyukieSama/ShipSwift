//
//  SWGlassOrb.swift
//  ShipSwift
//
//  Adapted from Inferno's "Warping Loupe" by Paul Hudson
//  https://github.com/twostraws/Inferno
//  Licensed under the MIT License. Copyright (c) 2023 Paul Hudson and other authors.
//  Original copyright and license notice retained as required by MIT.
//  See ShipSwift ACKNOWLEDGEMENTS for the full license text.
//
//  Wraps any view in a draggable glass orb via a SwiftUI Metal `layerEffect`.
//  Inside the circular orb the underlying content is magnified and bent with a
//  spherical (barrel) warp; a cool Fresnel rim, an upper-left specular
//  hot-spot, and optional rim RGB dispersion make it read as a solid glass
//  ball rather than a flat magnifier. Drag the orb to sweep it across the
//  content and watch the refraction change.
//
//  Requires iOS 17+ / macOS 14+ (SwiftUI `ShaderLibrary`,
//  `Shader`/`ShaderFunction`, Metal `stitchable`).
//
//  Usage:
//    // Wrap your own content — the orb starts centred and is draggable.
//    SWGlassOrb {
//        Image("poster").resizable().scaledToFill()
//    }
//
//    // Bigger, punchier ball
//    SWGlassOrb(radius: 160, magnification: 2.0, refraction: 0.7) {
//        myArtwork
//    }
//
//    // Convenience — no content; ships a built-in demo background
//    // (animated dark mesh gradient) so the refraction is easy to read.
//    SWGlassOrb()
//
//    // Demo / debug — gear button + live-tuning sheet.
//    // Requires an enclosing `NavigationStack`.
//    SWGlassOrb(showsControls: true)
//
//  Parameters:
//    - radius: Orb radius in points (default `120`).
//    - magnification: Peak zoom at the orb centre (default `1.6` = 1.6x).
//    - refraction: Strength of the spherical barrel warp in 0...1
//                  (default `0.5`). 0 = flat loupe zoom, 1 = strong bulge.
//    - edgeHighlight: Strength of the Fresnel rim + specular + shading in
//                     0...1 (default `0.6`).
//    - dispersion: Rim RGB-split strength in 0...1 (default `0.25`; 0 disables).
//    - showsControls: Attach a gear `ToolbarItem` that opens a live-tuning
//                     sheet (default `false`).
//

import SwiftUI

// MARK: - Main View

struct SWGlassOrb<Content: View>: View {
    /// Orb radius in points.
    var radius: CGFloat = 120

    /// Peak zoom at the orb centre (1.6 = 1.6x).
    var magnification: CGFloat = 1.6

    /// Strength of the spherical barrel warp, 0...1.
    var refraction: CGFloat = 0.5

    /// Strength of the Fresnel rim + specular + shading, 0...1.
    var edgeHighlight: CGFloat = 0.6

    /// Rim RGB-split strength, 0...1 (0 disables).
    var dispersion: CGFloat = 0.25

    /// When `true`, attaches a gear `ToolbarItem` that opens a live-tuning sheet.
    var showsControls: Bool = false

    private let content: Content

    init(
        radius: CGFloat = 120,
        magnification: CGFloat = 1.6,
        refraction: CGFloat = 0.5,
        edgeHighlight: CGFloat = 0.6,
        dispersion: CGFloat = 0.25,
        showsControls: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.magnification = magnification
        self.refraction = refraction
        self.edgeHighlight = edgeHighlight
        self.dispersion = dispersion
        self.showsControls = showsControls
        self.content = content()
    }

    var body: some View {
        if showsControls {
            SWGlassOrbControlled(initial: self, content: content)
        } else {
            SWGlassOrbRenderer(initial: self, content: content)
        }
    }
}

// MARK: - Convenience init (built-in demo background)

extension SWGlassOrb where Content == SWGlassOrbSampleBackground {
    /// Content-free initializer that ships a built-in demo background — an
    /// animated dark mesh gradient — so the orb's refraction is easy to read
    /// in isolation (Showcase / previews).
    init(
        radius: CGFloat = 120,
        magnification: CGFloat = 1.6,
        refraction: CGFloat = 0.5,
        edgeHighlight: CGFloat = 0.6,
        dispersion: CGFloat = 0.25,
        showsControls: Bool = false
    ) {
        self.init(
            radius: radius,
            magnification: magnification,
            refraction: refraction,
            edgeHighlight: edgeHighlight,
            dispersion: dispersion,
            showsControls: showsControls
        ) {
            SWGlassOrbSampleBackground()
        }
    }
}

// MARK: - Sample Background (for the content-free convenience init)

/// A self-contained demo backdrop: an animated **dark mesh gradient**. Deep
/// indigo / teal / violet tones drift slowly over time (driven by
/// `TimelineView`), so the orb's magnified refraction shows flowing color and
/// the cool Fresnel rim + specular hot-spot read clearly against the dark
/// ground. Requires iOS 18+ (`MeshGradient`).
struct SWGlassOrbSampleBackground: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Slow drift of the interior mesh points for a gentle flowing feel.
            let a = Float(sin(t * 0.50)) * 0.07
            let b = Float(cos(t * 0.40)) * 0.07
            let c = Float(sin(t * 0.62 + 1.0)) * 0.06

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    .init(0, 0),       .init(0.5 + a, 0),       .init(1, 0),
                    .init(0, 0.5 - b), .init(0.5 + c, 0.5 + a), .init(1, 0.5 + b),
                    .init(0, 1),       .init(0.5 - a, 1),       .init(1, 1)
                ],
                colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.16), // deep indigo
                    Color(red: 0.09, green: 0.06, blue: 0.26), // deep purple
                    Color(red: 0.03, green: 0.06, blue: 0.20), // deep blue
                    Color(red: 0.04, green: 0.15, blue: 0.30), // deep teal
                    Color(red: 0.18, green: 0.11, blue: 0.46), // brighter violet core
                    Color(red: 0.05, green: 0.22, blue: 0.36), // teal glow
                    Color(red: 0.02, green: 0.03, blue: 0.12), // near-black blue
                    Color(red: 0.06, green: 0.13, blue: 0.32), // muted teal
                    Color(red: 0.08, green: 0.05, blue: 0.22)  // deep indigo
                ]
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Renderer (shader binding + drag-to-move orb)

private struct SWGlassOrbRenderer<Content: View>: View {
    let initial: SWGlassOrb<Content>
    let content: Content

    // Orb centre in local view coordinates. nil until the first layout pass,
    // at which point it snaps to the geometry centre.
    @State private var center: CGPoint?
    // Live drag translation applied on top of `center` while dragging.
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            // Resolve the effective centre: stored centre (+ active drag) or,
            // before the first drag, the middle of the view.
            let base = center ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let c = CGPoint(x: base.x + dragOffset.width, y: base.y + dragOffset.height)

            // Magnification + refraction can pull samples in from far away;
            // budget the offset generously (radius scaled by magnification).
            let maxOffset = max(initial.radius * initial.magnification, initial.radius + 40)

            content
                .layerEffect(
                    ShaderLibrary.swGlassOrb(
                        .boundingRect,
                        .float2(Float(c.x), Float(c.y)),
                        .float(Float(initial.radius)),
                        .float(Float(initial.magnification)),
                        .float(Float(initial.refraction)),
                        .float(Float(initial.edgeHighlight)),
                        .float(Float(initial.dispersion))
                    ),
                    maxSampleOffset: CGSize(width: maxOffset, height: maxOffset)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in dragOffset = value.translation }
                        .onEnded { value in
                            // Fold the drag into the stored centre, clamped so
                            // the orb's centre stays inside the view bounds.
                            let nx = base.x + value.translation.width
                            let ny = base.y + value.translation.height
                            center = CGPoint(
                                x: min(max(nx, 0), geo.size.width),
                                y: min(max(ny, 0), geo.size.height)
                            )
                            dragOffset = .zero
                        }
                )
        }
    }
}

// MARK: - Controlled Wrapper (gear toolbar item + live sheet)

private struct SWGlassOrbControlled<Content: View>: View {
    @State private var radius: CGFloat
    @State private var magnification: CGFloat
    @State private var refraction: CGFloat
    @State private var edgeHighlight: CGFloat
    @State private var dispersion: CGFloat

    @State private var showSheet = false

    private let content: Content

    init(initial: SWGlassOrb<Content>, content: Content) {
        _radius        = State(initialValue: initial.radius)
        _magnification = State(initialValue: initial.magnification)
        _refraction    = State(initialValue: initial.refraction)
        _edgeHighlight = State(initialValue: initial.edgeHighlight)
        _dispersion    = State(initialValue: initial.dispersion)
        self.content = content
    }

    var body: some View {
        SWGlassOrbRenderer(
            initial: SWGlassOrb(
                radius: radius,
                magnification: magnification,
                refraction: refraction,
                edgeHighlight: edgeHighlight,
                dispersion: dispersion
            ) { content },
            content: content
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Glass Orb Controls")
            }
        }
        .sheet(isPresented: $showSheet) {
            SWGlassOrbControlsSheet(
                radius: $radius,
                magnification: $magnification,
                refraction: $refraction,
                edgeHighlight: $edgeHighlight,
                dispersion: $dispersion
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Controls Sheet

private struct SWGlassOrbControlsSheet: View {
    @Binding var radius: CGFloat
    @Binding var magnification: CGFloat
    @Binding var refraction: CGFloat
    @Binding var edgeHighlight: CGFloat
    @Binding var dispersion: CGFloat

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Lens") {
                    SWGlassOrbSliderRow(label: "Radius",        value: $radius,        range: 40...220,  step: 1)
                    SWGlassOrbSliderRow(label: "Magnification", value: $magnification, range: 1...3,     step: 0.05)
                    SWGlassOrbSliderRow(label: "Refraction",    value: $refraction,    range: 0...1,     step: 0.01)
                }
                Section("Glass") {
                    SWGlassOrbSliderRow(label: "Edge Highlight", value: $edgeHighlight, range: 0...1, step: 0.01)
                    SWGlassOrbSliderRow(label: "Dispersion",     value: $dispersion,    range: 0...1, step: 0.01)
                }
            }
            .navigationTitle("Glass Orb")
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

private struct SWGlassOrbSliderRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f", Double(value)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

// MARK: - Preview

#Preview("Default") {
    NavigationStack {
        SWGlassOrb(showsControls: true)
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
    }
}
