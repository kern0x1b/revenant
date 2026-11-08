import UIKit
import Vision

func recognized(candidate: VNRecognizedText) -> [CGRect] {
    var rectangles: [CGRect] = []
    let string = candidate.string
    string.enumerateSubstrings(in: string.startIndex ..< string.endIndex, options: .byWords) { _, substringRange, _, _ in
        if let rectangle = try? candidate.boundingBox(for: substringRange) {
            rectangles.append(rectangle.boundingBox)
        }
    }
    return rectangles
}

func landmarks(region: VNFaceLandmarkRegion2D, path: CGMutablePath, transform: CGAffineTransform, size: CGSize) {
    let points: [CGPoint] = region.normalizedPoints
    path.move(to: points[0], transform: transform)
    path.addLines(between: points, transform: transform)
    let inImage: [CGPoint] = region.pointsInImage(imageSize: size)
    path.addLines(between: inImage)
}

func contour(of contour: VNContour) -> [SIMD2<Float>] {
    return contour.normalizedPoints
}
