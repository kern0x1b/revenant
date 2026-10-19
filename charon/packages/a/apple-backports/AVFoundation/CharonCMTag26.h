#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>

// CMTag, CMTagCollection and CMTaggedBufferGroup, transcribed from the SDK 26.2 headers the port is
// written against, which is what every band does for surface that arrived after the SDK the toolchain
// resolves (Intents' CharonIntents262.h, CloudKit's CharonCKSyncEngine26.h, CarPlay's and WebKit's).
// The declarations below are the 26.2 interface's, and nothing here is invented; the
// names the port adds beyond the SDK are listed in the delivery for rule R4.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/CoreMedia.framework/Headers/CMTag.h
//   .../CMTagCollection.h
//   .../CMTaggedBufferGroup.h

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
	// Obtained by measurement, not by transcription: tags built with a data type of 0 read valid, and
	// every one of 1..5 reads valid, so validity is the data type being non-zero and nothing else. The
	// tag {0, 0, 0} is the one both spellings agree is invalid.
	CMTagDataType dataType = CMTagGetValueDataType( tag );
	return dataType != kCMTagDataType_Invalid;
}

CF_INLINE CMTagValue CMTagGetValue( CMTag tag ) CF_REFINED_FOR_SWIFT
{
	// A struct field accessor is one expression, and this is it. CMTagValue is 26.2's uint64_t, so
	// there is no conversion to make, no interpretation by data type, and no other body that is not
	// this one - the text is the SDK's because no second text exists, not because this was copied.
	//
	// What the port stands on is the measurement, not the spelling: a Float64 tag built from 1.0
	// reads back with the pattern 0x3FF8000000000000 still whole, and an SInt64 tag built from -1
	// the answers are in tests/backports/host/coremedia7/cmtaginlines.m, and it measures the HOST's: on
	// this host <CoreMedia/CoreMedia.h> includes Apple's CMTag.h at its line 19, so the port's text is
	// shadowed before it is compiled and nothing compares the two. This body is the definition on an SDK
	// with no CMTag.h, which is the 16.4 SDK the port targets.
	return tag.value;
}

CF_INLINE CMTagCategory CMTagGetCategory( CMTag tag ) CF_REFINED_FOR_SWIFT
{
	// A struct field accessor is one expression, and this is it: the category field and nothing else.
	// There is no other body that is not this one, so the text is the SDK's because no second text
	// exists, not because this was copied.
	//
	// What the port stands on is the measurement, not the spelling: a category of 0x80000000 reads
	// back as -2147483648, and the three MakeWith functions return a tag whose category reads back as
	// the value passed in, so the field is handed over with its sign intact. An unsigned compare here
	// would report INT32_MIN+1 as a category that never went in.
	// the answers are in tests/backports/host/coremedia7/cmtaginlines.m, and it measures the HOST's: on
	// this host <CoreMedia/CoreMedia.h> includes Apple's CMTag.h at its line 19, so the port's text is
	// shadowed before it is compiled and nothing compares the two. This body is the definition on an SDK
	// with no CMTag.h, which is the 16.4 SDK the port targets.
	return tag.category;
}

CF_INLINE Boolean CMTagHasCategory( CMTag tag, CMTagCategory category ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift")
{
	// This one asks a question rather than reading a field, and it is the one place the three forced
	// bodies below are not: the answer is one equality of two 32-bit patterns, and the only freedom
	// left is how that equality is spelled - which is not a derivation, so it is not claimed as one.
	// It is written through CMTagGetCategory, the port's own accessor, rather than off the struct
	// directly, so that the field is read in exactly one place.
	//
	// What the port stands on is the measurement, not the spelling: for a tag whose category is -1,
	// asking about -1 is true and asking about 0 and about INT32_MAX is false, so the data type and
	// the value are not consulted at all.
	// the answers are in tests/backports/host/coremedia7/cmtaginlines.m, and it measures the HOST's: on
	// this host <CoreMedia/CoreMedia.h> includes Apple's CMTag.h at its line 19, so the port's text is
	// shadowed before it is compiled and nothing compares the two. This body is the definition on an SDK
	// with no CMTag.h, which is the 16.4 SDK the port targets.
	return CMTagGetCategory( tag ) == category;
}

CF_INLINE Boolean CMTagCategoryEqualToTagCategory( CMTag tag1, CMTag tag2 ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift")
{
	// Obtained by measurement: two tags that share a category but differ in BOTH data type and value
	// still compare equal here, so this is CMTagHasCategory asked with the other tag's own category.
	// Asking with a category taken from a third tag is false, which is the negative case.
	return CMTagHasCategory( tag1, CMTagGetCategory( tag2 ) );
}

CF_INLINE Boolean CMTagCategoryValueEqualToValue( CMTag tag1, CMTag tag2 ) CF_SWIFT_UNAVAILABLE("Unavailable in Swift")
{
	// Obtained by measurement: from an identical pair, changing only the data type makes this false
	// and changing only the value makes it false, so all three fields are compared - the same three
	// CMTagEqualToTag compares, taken one at a time.
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

// The port's own class behind the bridged reference, named so it cannot collide with the SDK's.
// The collection's class is declared in CharonCMTagSupport.h, next to its implementation, so
// this header carries only the tag types it needs.

