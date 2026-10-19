//  The RELEASE's own export session, as the 7.0 metadataItemFilter composes over it, and nothing else.
//
//  What the release carries is measured, not assumed: `strings -a` over ~/.charon/dyld/6.1.3's armv7
//  cache answers 0 for `audioTimePitchAlgorithm`, `metadataItemFilter` and `setMetadataItemFilter:`, and 1
//  for `metadata`, `setMetadata:`, `asset`, `outputURL`, `outputFileType` and
//  `exportAsynchronouslyWithCompletionHandler:`; `strings -a` over the 7.0 and 7.1 armv7 caches answers 6
//  and 6 for `audioTimePitchAlgorithm`, so the guard the port installs reads a release that has it exactly
//  where the port must not write. -estimateOutputFileLength is 6.1.3's own (1) and is here for the same
//  reason, as a member the port adds none of.
//
//  Two rules this header keeps:
//
//    1. It declares NO member of the 7.0 family as the release's. The port's category adds
//       -metadataItemFilter/-setMetadataItemFilter:, and a member declared here AND implemented there
//       would hide a duplicate.
//    2. -audioTimePitchAlgorithm is NOT declared, and that is the point: the port's guard reads it to ask
//       "does the release carry 7.0", and a stand-in that declared it would make the port decline to
//       install and the check would measure nothing.
//
//  -exportAsynchronouslyWithCompletionHandler: IS implemented here, because it is the release's own
//  method and the port interposes on it rather than replacing it.
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

typedef NSString *AVAssetExportPreset;
typedef NSString *AVFileType;

extern NSString *const AVAssetExportPresetPassthrough;
extern NSString *const AVFileTypeQuickTimeMovie;

// The release's own AVAsset and its metadata: 4.3 carries -commonMetadata, and the port reads it and
// nothing else of the class.
// Apple's own filter class: the SDK declares no member of it but +metadataItemFilterForSharing, and the
// harness and the stand-in's filtering entry point both need that one. Declared here so the port's
// category signature can be spelled, and NOT implemented here: the class is Apple's, and the port does not
// define it either (AVFoundation/AVMetadataItemFilter.m carries it under Apple's name).
@interface AVMetadataItemFilter : NSObject
+ (AVMetadataItemFilter *)metadataItemFilterForSharing;
- (NSArray *)allowList;
@end

@interface AVAsset : NSObject
- (NSArray *)commonMetadata;
@end

// The release's own metadata item, as the export copies it: -identifier is what the filter matches on.
@interface AVMetadataItem : NSObject
- (NSString *)identifier;
+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                        filteredByMetadataItemFilter:(AVMetadataItemFilter *)filter;
@end

@interface AVAssetExportSession : NSObject

// The release's own. The asset initialiser from 4.3 and -exportAsynchronouslyWithCompletionHandler: with
// it, -metadata/-setMetadata: (metadata export predates 7.0), -asset, -outputURL and -outputFileType.
- (instancetype)initWithAsset:(AVAsset *)asset presetName:(AVAssetExportPreset)presetName;
- (AVAsset *)asset;
- (NSArray<AVMetadataItem *> *)metadata;
- (void)setMetadata:(NSArray<AVMetadataItem *> *)metadata;
- (NSURL *)outputURL;
- (void)setOutputURL:(NSURL *)outputURL;
- (AVFileType)outputFileType;
- (void)setOutputFileType:(AVFileType)outputFileType;
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;

// The port's own, not the release's, and not implemented here: the port's category adds them.
- (AVMetadataItemFilter *)metadataItemFilter;
- (void)setMetadataItemFilter:(AVMetadataItemFilter *)metadataItemFilter;

@end