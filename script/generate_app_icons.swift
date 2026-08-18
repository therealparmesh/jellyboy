#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let repositoryRoot = URL(fileURLWithPath: CommandLine.arguments[0])
    .standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let sourceURL = repositoryRoot.appendingPathComponent("Design/AppIcon.svg")
let iconSetURL = repositoryRoot.appendingPathComponent(
    "Resources/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)
let sizes = [16, 20, 29, 32, 40, 58, 60, 64, 80, 87, 120, 128, 152, 167, 180, 256, 512, 1024]
let pixels = [
    "................",
    "................",
    "......RRRR......",
    "....RRRRRRRR....",
    "...RRRRRRRRRR...",
    "..RRWWWWWWWWRR..",
    ".RRWWWWWWWWWWRR.",
    ".RRWWRWWWWRWWRR.",
    ".RRWWWWWWWWWWRR.",
    ".RRWRWWWWWWRWRR.",
    "..RRWWWWWWWWRR..",
    "...RRR.RR.RRR...",
    "..RRRR.RR.RRRR..",
    "..RRR..RR..RRR..",
    "................",
    "................",
]
let palette: [Character: (red: UInt8, green: UInt8, blue: UInt8, hex: String)] = [
    ".": (0, 0, 0, "#000000"),
    "R": (255, 132, 132, "#ff8484"),
    "W": (255, 255, 255, "#ffffff"),
]

guard pixels.count == 16, pixels.allSatisfy({ $0.count == 16 }) else {
    fatalError("The app icon must be a 16-by-16 pixel map")
}

func svgRectangles(for value: Character) -> String {
    var rectangles: [String] = []
    for (row, line) in pixels.enumerated() {
        let values = Array(line)
        var column = 0
        while column < values.count {
            guard values[column] == value else {
                column += 1
                continue
            }
            let start = column
            while column < values.count, values[column] == value {
                column += 1
            }
            rectangles.append(
                "    <rect x=\"\(start * 64)\" y=\"\(row * 64)\" width=\"\((column - start) * 64)\" height=\"64\"/>"
            )
        }
    }
    return rectangles.joined(separator: "\n")
}

let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" shape-rendering="crispEdges">
      <rect width="1024" height="1024" fill="\(palette["."]!.hex)"/>
      <g fill="\(palette["R"]!.hex)">
    \(svgRectangles(for: "R"))
      </g>
      <g fill="\(palette["W"]!.hex)">
    \(svgRectangles(for: "W"))
      </g>
    </svg>
    """
try Data(svg.utf8).write(to: sourceURL, options: .atomic)

let colorSpace = CGColorSpaceCreateDeviceRGB()
for size in sizes {
    var bitmap = [UInt8](repeating: 0, count: size * size * 4)
    for row in 0..<size {
        let sourceRow = min(row * pixels.count / size, pixels.count - 1)
        let sourcePixels = Array(pixels[sourceRow])
        for column in 0..<size {
            let sourceColumn = min(column * sourcePixels.count / size, sourcePixels.count - 1)
            let color = palette[sourcePixels[sourceColumn]]!
            let offset = (row * size + column) * 4
            bitmap[offset] = color.red
            bitmap[offset + 1] = color.green
            bitmap[offset + 2] = color.blue
            bitmap[offset + 3] = 255
        }
    }

    let image = bitmap.withUnsafeBytes { buffer -> CGImage? in
        guard let provider = CGDataProvider(data: Data(buffer) as CFData) else { return nil }
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.union(
                CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    guard let image else {
        fatalError("Could not rasterize the \(size)-pixel icon")
    }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode the \(size)-pixel icon")
    }
    try data.write(
        to: iconSetURL.appendingPathComponent("AppIcon-\(size).png"),
        options: .atomic
    )
}
