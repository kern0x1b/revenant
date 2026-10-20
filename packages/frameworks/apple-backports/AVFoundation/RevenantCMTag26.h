#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>

#if !__has_include(<CoreMedia/CMTag.h>)

typedef CF_ENUM(FourCharCode, CMTagCategory)
{
	kCMTagCategory_Undefined CF_REFINED_FOR_SWIFT	= 0,
	kCMTagCategory_MediaType 						= 'mdia',
	kCMTagCategory_MediaSubType 					= 'msub',
	kCMTagCategory_TrackID 							= 'trak',
	kCMTagCategory_ChannelID 						= 'vchn',
	kCMTagCategory_VideoLayerID						= 'vlay',
	kCMTagCategory_PixelFormat 						= 'pixf',
	kCMTagCategory_PackingType						= 'pack',
	kCMTagCategory_ProjectionType 					= 'proj',
	kCMTagCategory_StereoView 					= 'eyes',
	kCMTagCategory_StereoViewInterpretation 	= 'eyip',
} CF_REFINED_FOR_SWIFT;

typedef CF_ENUM( uint32_t, CMTagDataType ) {
	kCMTagDataType_Invalid CF_REFINED_FOR_SWIFT	= 0,
	kCMTagDataType_SInt64						= 2,
	kCMTagDataType_Float64 						= 3,
	kCMTagDataType_OSType 						= 5,
	kCMTagDataType_Flags 						= 7,
} CF_REFINED_FOR_SWIFT;

typedef uint64_t CMTagValue CF_REFINED_FOR_SWIFT;

struct CMTag {
	CMTagCategory category;
	CMTagDataType dataType;
	CMTagValue value;
} CF_REFINED_FOR_SWIFT;
typedef struct CMTag CMTag CF_REFINED_FOR_SWIFT;

CM_EXPORT CMTagDataType CMTagGetValueDataType( CMTag tag );

CF_INLINE Boolean CMTagIsValid( CMTag tag ) CF_REFINED_FOR_SWIFT
{
	CMTagDataType dataType = CMTagGetValueDataType( tag );
	return dataType != kCMTagDataType_Invalid;
}

CF_INLINE CMTagValue CMTagGetValue( CMTag tag ) CF_REFINED_FOR_SWIFT
{
	return tag.value;
}

CF_INLINE CMTagCategory CMTagGetCategory( CMTag tag ) CF_REFINED_FOR_SWIFT
{
	return tag.category;
}

CF_INLINE Boolean CMTagHasCategory( CMTag tag, CMTagCategory category ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift")
{
	return CMTagGetCategory( tag ) == category;
}

CF_INLINE Boolean CMTagCategoryEqualToTagCategory( CMTag tag1, CMTag tag2 ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift")
{
	return CMTagHasCategory( tag1, CMTagGetCategory( tag2 ) );
}

CF_INLINE Boolean CMTagCategoryValueEqualToValue( CMTag tag1, CMTag tag2 ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift")
{
	return CMTagHasCategory( tag1, CMTagGetCategory( tag2 ) ) &&
	       CMTagGetValueDataType( tag1 ) == CMTagGetValueDataType( tag2 ) &&
	       CMTagGetValue( tag1 ) == CMTagGetValue( tag2 );
}

CM_EXPORT Boolean CMTagHasSInt64Value( CMTag tag ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT int64_t CMTagGetSInt64Value( CMTag tag ) CF_REFINED_FOR_SWIFT;

CM_EXPORT Boolean CMTagHasFloat64Value( CMTag tag ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT Float64 CMTagGetFloat64Value( CMTag tag ) CF_REFINED_FOR_SWIFT;

CM_EXPORT Boolean CMTagHasOSTypeValue( CMTag tag ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT OSType CMTagGetOSTypeValue( CMTag tag ) CF_REFINED_FOR_SWIFT;

CM_EXPORT Boolean CMTagHasFlagsValue( CMTag tag ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT uint64_t CMTagGetFlagsValue( CMTag tag ) CF_REFINED_FOR_SWIFT;

CM_EXPORT CMTag CMTagMakeWithSInt64Value( CMTagCategory category, int64_t value ) CF_REFINED_FOR_SWIFT;

CM_EXPORT CMTag CMTagMakeWithFloat64Value( CMTagCategory category, Float64 value ) CF_REFINED_FOR_SWIFT;

CM_EXPORT CMTag CMTagMakeWithOSTypeValue( CMTagCategory category, OSType value ) CF_REFINED_FOR_SWIFT;

CM_EXPORT CMTag CMTagMakeWithFlagsValue( CMTagCategory category, uint64_t flagsForTag ) CF_REFINED_FOR_SWIFT;

CM_EXPORT Boolean CMTagEqualToTag( CMTag tag1, CMTag tag2 ) CF_REFINED_FOR_SWIFT;

CM_EXPORT CFComparisonResult CMTagCompare( CMTag tag1, CMTag tag2 ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT CFHashCode CMTagHash( CMTag tag) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT CFStringRef CM_NULLABLE CMTagCopyDescription(
    CFAllocatorRef CM_NULLABLE allocator,
    CMTag tag ) CF_REFINED_FOR_SWIFT;

CM_EXPORT CFDictionaryRef CM_NULLABLE CMTagCopyAsDictionary(
    CMTag tag,
    CFAllocatorRef CM_NULLABLE allocator) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CM_EXPORT CMTag CMTagMakeFromDictionary(
    CFDictionaryRef CM_NONNULL dict) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

typedef CF_ENUM(OSStatus, CMTagCollectionError)
{
	kCMTagCollectionError_ParamErr 							= -15740,
	kCMTagCollectionError_AllocationFailed 					= -15741,
	kCMTagCollectionError_InternalError 					= -15742,
	kCMTagCollectionError_InvalidTag						= -15743,
	kCMTagCollectionError_InvalidTagCollectionDictionary	= -15744,
	kCMTagCollectionError_InvalidTagCollectionData			= -15745,
	kCMTagCollectionError_TagNotFound						= -15746,
	kCMTagCollectionError_InvalidTagCollectionDataVersion 	= -15747,
	kCMTagCollectionError_ExhaustedBufferSize 				= -15748,
	kCMTagCollectionError_NotYetImplemented					= -15749
} CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

typedef Boolean (*CMTagCollectionTagFilterFunction)(CMTag tag, void *context) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

typedef const struct CM_BRIDGED_TYPE(id) OpaqueCMTagCollection * CMTagCollectionRef
    CF_REFINED_FOR_SWIFT;
typedef struct CM_BRIDGED_TYPE(id) OpaqueCMutableTagCollection * CMMutableTagCollectionRef CF_SWIFT_UNAVAILABLE("Unavailable in Swift");
typedef struct CM_BRIDGED_TYPE(id) OpaqueCMTaggedBufferGroup * CMTaggedBufferGroupRef
    CF_REFINED_FOR_SWIFT;

typedef void (*CMTagCollectionApplierFunction)(CMTag tag, void *context) CF_SWIFT_UNAVAILABLE("Unavailable in Swift");
typedef CMTag (*CMTagCollectionApplyUntilResult)(void);

CF_EXPORT const CFStringRef kCMTagCategoryKey CF_SWIFT_UNAVAILABLE("Unavailable in Swift");
CF_EXPORT const CFStringRef kCMTagValueKey CF_SWIFT_UNAVAILABLE("Unavailable in Swift");
CF_EXPORT const CFStringRef kCMTagDataTypeKey CF_SWIFT_UNAVAILABLE("Unavailable in Swift");

CF_EXPORT const CMTag kCMTagInvalid CF_REFINED_FOR_SWIFT;

#endif
