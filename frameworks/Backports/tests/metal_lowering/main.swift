import CoreGraphics
import CoreVideo
import IOSurface
import Metal

func textureDescriptors(device: MTLDevice, buffer: MTLBuffer, pixelFormat: MTLPixelFormat) -> [MTLTexture?] {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: 64, height: 64, mipmapped: false)
    descriptor.storageMode = .private
    descriptor.usage = [.shaderRead, .shaderWrite]
    let fromDevice = device.makeTexture(descriptor: descriptor)

    let renderTarget = MTLTextureDescriptor()
    renderTarget.pixelFormat = pixelFormat
    renderTarget.width = 64
    renderTarget.height = 64
    renderTarget.storageMode = .shared
    renderTarget.usage = .renderTarget
    let fromBuffer = buffer.makeTexture(descriptor: renderTarget, offset: 0, bytesPerRow: 256)
    return [fromDevice, fromBuffer]
}

func ioSurfaceTexture(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLTexture? {
    let properties: [String: Any] = [
        kIOSurfaceWidth as String: 64,
        kIOSurfaceHeight as String: 64,
        kIOSurfaceBytesPerElement as String: 4,
        kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA,
    ]
    guard let ioSurface: IOSurfaceRef = IOSurfaceCreate(properties as CFDictionary) else {
        return nil
    }
    if let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB),
       let propertyList = colorSpace.copyPropertyList() {
        IOSurfaceSetValue(ioSurface, kIOSurfaceColorSpace, propertyList)
    }

    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = pixelFormat
    descriptor.width = 64
    descriptor.height = 64
    descriptor.storageMode = .shared
    descriptor.usage = .renderTarget
    return device.makeTexture(descriptor: descriptor, iosurface: ioSurface, plane: 0)
}

func computePipeline(device: MTLDevice, descriptor: MTLComputePipelineDescriptor) -> MTLComputePipelineState? {
    return try? device.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
}
