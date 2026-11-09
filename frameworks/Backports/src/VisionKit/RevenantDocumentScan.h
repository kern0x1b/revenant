#ifndef REVENANT_DOCUMENT_SCAN_H
#define REVENANT_DOCUMENT_SCAN_H

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#include "RevenantDocumentLive.h"

@interface RevenantDocumentPage : NSObject

@property (nonatomic, readonly) NSData *jpeg;
@property (nonatomic, readonly) size_t width;
@property (nonatomic, readonly) size_t height;
@property (nonatomic, readonly) RevenantDocumentQuad quad;
@property (nonatomic, readonly) BOOL detected;

@end

#ifdef __cplusplus
extern "C" {
#endif

RevenantDocumentPage *RevenantDocumentPageFromJPEG(NSData *still, const RevenantDocumentQuad *hint, size_t maximum_side, CGFloat quality);

#ifdef __cplusplus
}
#endif

#endif
