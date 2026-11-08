import CoreGraphics
import Foundation
import simd

extension VNFaceLandmarkRegion2D {
    @nonobjc public var normalizedPoints: [CGPoint] {
        let count = Int(pointCount)
        guard count > 0 else {
            return []
        }
        return Array(UnsafeBufferPointer(start: __normalizedPoints, count: count))
    }

    @nonobjc public func pointsInImage(imageSize: CGSize) -> [CGPoint] {
        let count = Int(pointCount)
        guard count > 0 else {
            return []
        }
        return Array(UnsafeBufferPointer(start: __pointsInImage(imageSize: imageSize), count: count))
    }
}

extension VNRecognizedText {
    @nonobjc public func boundingBox(for range: Range<String.Index>) throws -> VNRectangleObservation? {
        var failure: NSError?
        let observation = __boundingBox(for: NSRange(range, in: string), error: &failure)
        if let failure = failure {
            throw failure
        }
        return observation
    }
}

extension VNContour {
    @nonobjc public var normalizedPoints: [simd_float2] {
        let count = Int(pointCount)
        guard count > 0 else {
            return []
        }
        return Array(UnsafeBufferPointer(start: __normalizedPoints, count: count))
    }
}
