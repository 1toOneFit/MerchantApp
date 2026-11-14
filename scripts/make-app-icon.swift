// Draws the MerchantCatalog app icon: a 2x2 catalog grid on a teal-to-navy gradient,
// with one amber tile for saved items. 1024 x 1024, opaque (the App Store rejects icons with alpha).
//
// Usage: swift scripts/make-app-icon.swift MerchantCatalog/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift make-app-icon.swift <output.png>\n".utf8))
    exit(1)
}

let size = 1024
let side = CGFloat(size)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(srgbRed: 0.06, green: 0.45, blue: 0.50, alpha: 1),
        CGColor(srgbRed: 0.07, green: 0.20, blue: 0.38, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side), end: CGPoint(x: side, y: 0), options: [])

let tile: CGFloat = 250
let gap: CGFloat = 64
let radius: CGFloat = 56
let origin = (side - (tile * 2 + gap)) / 2
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.94)
let amber = CGColor(srgbRed: 1, green: 0.76, blue: 0.28, alpha: 1)

for row in 0..<2 {
    for column in 0..<2 {
        let rect = CGRect(
            x: origin + CGFloat(column) * (tile + gap),
            y: origin + CGFloat(row) * (tile + gap),
            width: tile, height: tile
        )
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        let isTopRight = row == 1 && column == 1  // Core Graphics' y axis points up.
        context.setFillColor(isTopRight ? amber : white)
        context.fillPath()
    }
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard
    let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    FileHandle.standardError.write(Data("failed to create the image\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("failed to write \(url.path)\n".utf8))
    exit(1)
}
