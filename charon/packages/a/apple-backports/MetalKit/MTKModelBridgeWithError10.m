#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>

MDLVertexFormat CharonMDLFormatFromMetal(MTLVertexFormat format)
{
    switch (format) {
        case MTLVertexFormatFloat: return MDLVertexFormatFloat;
        case MTLVertexFormatFloat2: return MDLVertexFormatFloat2;
        case MTLVertexFormatFloat3: return MDLVertexFormatFloat3;
        case MTLVertexFormatFloat4: return MDLVertexFormatFloat4;
        case MTLVertexFormatInt: return MDLVertexFormatInt;
        case MTLVertexFormatInt2: return MDLVertexFormatInt2;
        case MTLVertexFormatInt3: return MDLVertexFormatInt3;
        case MTLVertexFormatInt4: return MDLVertexFormatInt4;
        case MTLVertexFormatUInt: return MDLVertexFormatUInt;
        case MTLVertexFormatUInt2: return MDLVertexFormatUInt2;
        case MTLVertexFormatUInt3: return MDLVertexFormatUInt3;
        case MTLVertexFormatUInt4: return MDLVertexFormatUInt4;
        case MTLVertexFormatUChar4Normalized: return MDLVertexFormatUChar4Normalized;
        case MTLVertexFormatChar4Normalized: return MDLVertexFormatChar4Normalized;
        case MTLVertexFormatUShort2Normalized: return MDLVertexFormatUShort2Normalized;
        case MTLVertexFormatShort2Normalized: return MDLVertexFormatShort2Normalized;
        case MTLVertexFormatHalf2: return MDLVertexFormatHalf2;
        case MTLVertexFormatHalf3: return MDLVertexFormatHalf3;
        case MTLVertexFormatHalf4: return MDLVertexFormatHalf4;
        default: return MDLVertexFormatInvalid;
    }
}

MTLVertexFormat CharonMetalFormatFromMDL(MDLVertexFormat format)
{
    switch (format) {
        case MDLVertexFormatFloat: return MTLVertexFormatFloat;
        case MDLVertexFormatFloat2: return MTLVertexFormatFloat2;
        case MDLVertexFormatFloat3: return MTLVertexFormatFloat3;
        case MDLVertexFormatFloat4: return MTLVertexFormatFloat4;
        case MDLVertexFormatInt: return MTLVertexFormatInt;
        case MDLVertexFormatInt2: return MTLVertexFormatInt2;
        case MDLVertexFormatInt3: return MTLVertexFormatInt3;
        case MDLVertexFormatInt4: return MTLVertexFormatInt4;
        case MDLVertexFormatUInt: return MTLVertexFormatUInt;
        case MDLVertexFormatUInt2: return MTLVertexFormatUInt2;
        case MDLVertexFormatUInt3: return MTLVertexFormatUInt3;
        case MDLVertexFormatUInt4: return MTLVertexFormatUInt4;
        case MDLVertexFormatUChar4Normalized: return MTLVertexFormatUChar4Normalized;
        case MDLVertexFormatChar4Normalized: return MTLVertexFormatChar4Normalized;
        case MDLVertexFormatUShort2Normalized: return MTLVertexFormatUShort2Normalized;
        case MDLVertexFormatShort2Normalized: return MTLVertexFormatShort2Normalized;
        case MDLVertexFormatHalf2: return MTLVertexFormatHalf2;
        case MDLVertexFormatHalf3: return MTLVertexFormatHalf3;
        case MDLVertexFormatHalf4: return MTLVertexFormatHalf4;
        default: return MTLVertexFormatInvalid;
    }
}

MDLVertexDescriptor *MTKModelIOVertexDescriptorFromMetalWithError(MTLVertexDescriptor *metalDescriptor, NSError **error)
{
    MDLVertexDescriptor *descriptor = [[MDLVertexDescriptor alloc] init];
    for (NSUInteger index = 0; index < 31; index++) {
        MTLVertexAttributeDescriptor *attribute = metalDescriptor.attributes[index];
        if (attribute.format == MTLVertexFormatInvalid)
            continue;
        MDLVertexFormat format = CharonMDLFormatFromMetal(attribute.format);
        if (format == MDLVertexFormatInvalid) {
            if (error)
                *error = [NSError errorWithDomain:MTKModelErrorDomain code:1 userInfo:@{MTKModelErrorKey: @(index), NSLocalizedDescriptionKey: @"this port does not map every MTLVertexFormat to a Model I/O vertex format"}];
            return nil;
        }
        [descriptor.attributes addObject:[[MDLVertexAttribute alloc] initWithName:@"" format:format offset:attribute.offset bufferIndex:attribute.bufferIndex]];
    }
    for (NSUInteger index = 0; index < 31; index++) {
        MTLVertexBufferLayoutDescriptor *layout = metalDescriptor.layouts[index];
        if (layout.stride > 0)
            [descriptor.layouts addObject:[[MDLVertexBufferLayout alloc] initWithStride:layout.stride]];
    }
    return descriptor;
}

MTLVertexDescriptor *MTKMetalVertexDescriptorFromModelIOWithError(MDLVertexDescriptor *modelIODescriptor, NSError **error)
{
    MTLVertexDescriptor *descriptor = [[MTLVertexDescriptor alloc] init];
    NSUInteger index = 0;
    for (MDLVertexAttribute *attribute in modelIODescriptor.attributes) {
        if (attribute.format == MDLVertexFormatInvalid) {
            index++;
            continue;
        }
        MTLVertexFormat format = CharonMetalFormatFromMDL(attribute.format);
        if (format == MTLVertexFormatInvalid) {
            if (error)
                *error = [NSError errorWithDomain:MTKModelErrorDomain code:2 userInfo:@{MTKModelErrorKey: @(index), NSLocalizedDescriptionKey: @"this port does not map every Model I/O vertex format to an MTLVertexFormat"}];
            return nil;
        }
        descriptor.attributes[index].format = format;
        descriptor.attributes[index].offset = attribute.offset;
        descriptor.attributes[index].bufferIndex = attribute.bufferIndex;
        index++;
    }
    index = 0;
    for (MDLVertexBufferLayout *layout in modelIODescriptor.layouts)
        descriptor.layouts[index++].stride = layout.stride;
    return descriptor;
}

// The four single-value forms, which the header declares beside the WithError ones. Each is the same
// conversion with the error pointer dropped: the WithError form reports a format neither table has,
// and a format neither table has is one this port's shaders cannot be written against, so the value
// form answers the same way the header's pair does - the conversion is made, and it returns what the
// sibling returns with its error pointer unused.
