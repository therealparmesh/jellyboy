#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count > 1 else {
    fatalError("Pass at least one image path")
}

let output = FileHandle.standardOutput
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCache: false] as CFDictionary
        )
    else {
        fatalError("Could not decode \(path)")
    }

    let bytesPerRow = image.width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    let didRender = pixels.withUnsafeMutableBytes { buffer in
        guard
            let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                    | CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard didRender else {
        fatalError("Could not create a pixel buffer for \(path)")
    }

    output.write(Data("\(url.lastPathComponent)\0\(image.width)x\(image.height)\0".utf8))
    output.write(Data(pixels))
}
