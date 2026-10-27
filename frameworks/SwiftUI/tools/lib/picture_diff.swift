import CoreGraphics
import CoreText
import Foundation
import ImageIO

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fputs("picture-diff: cannot read \(path)\n", stderr)
        exit(2)
    }
    return image
}

func pixels(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return data
}

func sheet(_ output: String, _ columns: Int, _ entries: [String]) {
    let cellWidth = 190
    let cellHeight = 280
    let rows = (entries.count + columns - 1) / columns
    let context = CGContext(data: nil, width: columns * cellWidth, height: rows * cellHeight, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    let font = CTFontCreateWithName("Helvetica" as CFString, 15, nil)
    for (index, entry) in entries.enumerated() {
        let parts = entry.split(separator: "=", maxSplits: 1).map(String.init)
        let image = load(parts[1])
        let scale = min(180 / CGFloat(image.width), 230 / CGFloat(image.height))
        let drawWidth = CGFloat(image.width) * scale
        let drawHeight = CGFloat(image.height) * scale
        let originX = CGFloat((index % columns) * cellWidth)
        let originY = CGFloat((rows - 1 - index / columns) * cellHeight)
        context.draw(image, in: CGRect(x: originX + (CGFloat(cellWidth) - drawWidth) / 2, y: originY + 40 + (230 - drawHeight) / 2,
                                       width: drawWidth, height: drawHeight))
        let attributes = [kCTFontAttributeName as String: font] as CFDictionary
        let text = CFAttributedStringCreate(nil, parts[0] as CFString, attributes)!
        context.textPosition = CGPoint(x: originX + 6, y: originY + 12)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

let arguments = CommandLine.arguments
if arguments.count >= 4 && arguments[1] == "sheet" {
    sheet(arguments[2], Int(arguments[3])!, Array(arguments.dropFirst(4)))
    exit(0)
}
guard arguments.count >= 3 else {
    fputs("usage: picture-diff REFERENCE CANDIDATE [x0,y0,x1,y1 ...] | sheet OUTPUT COLUMNS LABEL=PATH ...\n", stderr)
    exit(2)
}
let reference = load(arguments[1])
let candidate = load(arguments[2])
let width = reference.width
let height = reference.height
let scaled = candidate.width != width || candidate.height != height
let expected = pixels(reference, width: width, height: height)
let actual = pixels(candidate, width: width, height: height)
let masks: [[Double]] = arguments.dropFirst(3).map { $0.split(separator: ",").map { Double($0)! } }
let channelLimit = 24

var total = 0.0
var compared = 0
var minX = width, minY = height, maxX = -1, maxY = -1
for y in 0..<height {
    for x in 0..<width {
        let fx = Double(x) / Double(width)
        let fy = Double(y) / Double(height)
        if masks.contains(where: { fx >= $0[0] && fy >= $0[1] && fx < $0[2] && fy < $0[3] }) {
            continue
        }
        let index = (y * width + x) * 4
        var sum = 0
        var largest = 0
        for channel in 0..<3 {
            let difference = abs(Int(expected[index + channel]) - Int(actual[index + channel]))
            sum += difference
            largest = max(largest, difference)
        }
        total += Double(sum) / 3
        compared += 1
        if largest > channelLimit {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
}
let mean = compared > 0 ? total / Double(compared) : 0
let box = maxX < 0 ? "none" : "\(minX),\(minY),\(maxX),\(maxY)"
print(String(format: "mean=%.4f", mean), "size=\(width)x\(height)", "scaled=\(scaled ? "yes" : "no")", "box=\(box)")
