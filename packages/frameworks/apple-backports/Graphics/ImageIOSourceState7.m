#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

void CGImageSourceRemoveCacheAtIndex(CGImageSourceRef source, size_t index)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"CGImageSourceRemoveCacheAtIndex: the decoded image cache belongs to the release's own image "
              @"source, which has no public way to be freed, so nothing was freed.");
    });
    (void)source;
    (void)index;
}
