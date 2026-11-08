@_exported import AVFoundation
import CoreFoundation
import CoreMedia
import Foundation

#if os(iOS)

extension AVCapturePhotoOutput {
  @nonobjc
  public func supportedPhotoPixelFormatTypes(for fileType: AVFileType) -> [OSType] {
    return __supportedPhotoPixelFormatTypes(forFileType: fileType).map { $0.uint32Value } as [OSType]
  }

  @nonobjc
  public func supportedRawPhotoPixelFormatTypes(for fileType: AVFileType) -> [OSType] {
    return __supportedRawPhotoPixelFormatTypes(forFileType: fileType).map { $0.uint32Value } as [OSType]
  }
}

extension AVCaptureDevice.Format {
  @available(iOS 16.0, *)
  @nonobjc
  public var supportedMaxPhotoDimensions: [CMVideoDimensions] {
    return __supportedMaxPhotoDimensions.map { value in
      var dimensions = CMVideoDimensions()
      value.getValue(&dimensions)
      return dimensions
    }
  }

  @available(iOS 16.0, *)
  @nonobjc
  public var secondaryNativeResolutionZoomFactors: [CGFloat] {
    return __secondaryNativeResolutionZoomFactors.map { CGFloat($0.doubleValue) }
  }

  @available(iOS, introduced: 16.0, deprecated: 17.2, message: "Use AVCaptureDevice.Format.supportedVideoZoomRangesForDepthDataDelivery instead")
  @nonobjc
  public var supportedVideoZoomFactorsForDepthDataDelivery: [CGFloat] {
    return __supportedVideoZoomFactorsForDepthDataDelivery.map { CGFloat($0.doubleValue) }
  }

  @nonobjc
  public var supportedVideoZoomRangesForDepthDataDelivery: [ClosedRange<CGFloat>] {
    return __supportedVideoZoomRangesForDepthDataDelivery.map { $0.minZoomFactor...$0.maxZoomFactor }
  }

  @nonobjc
  public var systemRecommendedVideoZoomRange: ClosedRange<CGFloat>? {
    return __systemRecommendedVideoZoomRange.map { $0.minZoomFactor...$0.maxZoomFactor }
  }

  @nonobjc
  public var systemRecommendedExposureBiasRange: ClosedRange<Float>? {
    return __systemRecommendedExposureBiasRange.map { $0.minExposureBias...$0.maxExposureBias }
  }
}

#endif
