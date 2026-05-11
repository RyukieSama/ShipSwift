//
//  SWImageThumbnail.swift
//  ShipSwift
//
//  Square image thumbnail with a same-named ColorSet fallback. Designed for
//  product cards, list rows, cart items, and detail headers where a polished
//  image tile is needed without bespoke loading-state UI.
//
//  Killer feature -- same-name ColorSet as fallback:
//    The thumbnail expects your Asset Catalog to contain both an image set and
//    a color set sharing the same name (e.g. `Drink_NaiCha` image + `Drink_NaiCha`
//    color). `Color(imageName)` is rendered first as a solid background, and
//    `Image(imageName)` is drawn on top with `.scaledToFill()`. As a result:
//
//      * If the image asset is missing or still decoding, the tile shows the
//        brand-appropriate tint instead of a generic gray placeholder.
//      * If the image is partially transparent (e.g. a PNG with rounded edges),
//        the tint fills the negative space.
//      * Empty / WIP states ship as a colored tile, not a broken-image icon.
//
//    If only an image (no matching color) is provided, SwiftUI silently falls
//    back to clear -- the tile still renders correctly. The ColorSet is optional
//    polish, not a hard requirement.
//
//  Usage:
//    // Basic -- 120pt square, 18pt corner radius
//    SWImageThumbnail(imageName: "Drink_NaiCha")
//
//    // Custom size and corner radius for cart rows
//    SWImageThumbnail(imageName: "Drink_YangZhi", size: 60, cornerRadius: 12)
//
//    // Large hero thumbnail
//    SWImageThumbnail(imageName: "Drink_KaoNai", size: 240, cornerRadius: 24)
//
//  Parameters:
//    - imageName: String         -- Asset catalog name. Looked up as both an
//                                   image set and (optionally) a color set.
//    - size: CGFloat             -- Tile width and height (default 120)
//    - cornerRadius: CGFloat     -- Continuous corner radius (default 18)
//
//  Created by Wei Zhong on 5/11/26.
//

import SwiftUI

struct SWImageThumbnail: View {
    // MARK: - Properties

    /// Asset catalog name used to look up both the image set and an optional
    /// same-named color set that serves as a fallback tint.
    let imageName: String

    /// Tile width and height. The thumbnail is always square.
    var size: CGFloat = 120

    /// Continuous corner radius applied to both the clip shape and the border.
    var cornerRadius: CGFloat = 18

    // MARK: - Body

    var body: some View {
        Color(imageName)
            .overlay(
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Falls back to clear if neither image nor color is registered --
        // useful in previews where assets are not yet wired up.
        SWImageThumbnail(imageName: "PreviewMissingAsset")
        SWImageThumbnail(imageName: "PreviewMissingAsset", size: 80)
        SWImageThumbnail(imageName: "PreviewMissingAsset", size: 60, cornerRadius: 12)
    }
    .padding()
}
