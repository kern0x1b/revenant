// CGImageSourceRemoveCacheAtIndex, and the two auxiliary-data rows around it: what iOS 6 cannot answer.
//
// Every function of the iOS 7 surface that takes or hands back an object of ImageIO's own is a decision
// here, not a row to be implemented, and the decision is the same for five of them: the object is one the
// release built and this library did not lay out.
//
// MEASURED, tools/cache-index/first-rung.lua over the 50 held rungs (2026-09-30,
// .agent-work/runs/io-rungs.txt), the symbols this file's decisions rest on:
//   _CGImageDestinationCopyImageSource             first held rung 7.0
//   _CGImageDestinationAddAuxiliaryDataInfo       first held rung 11.0
//   _CGImageSourceCopyAuxiliaryDataInfoAtIndex     first held rung 11.0
//   _CGImageSourceGetPrimaryImageIndex             first held rung 12.0
//   _CGImageSourceRemoveCacheAtIndex              first held rung 7.0
// No rung below 7.0 carries any of them, and iOS 6.1.3 exports no other symbol that answers the same
// question: the release's own CGImageSourceCopyMetadataAtIndex hands back an object of its own private
// class, and nothing public converts that object to or from anything else.

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

// "Deletes all the decoded image data for the image at the specified index and frees the memory."
// The decoded data is the release's own, held inside the release's source object: there is no public
// mechanism on iOS 6 that frees it, and this function has never carried the decoded image itself. Doing
// nothing is a safe reading of the call - nothing is written, nothing is dropped from the file, and the
// memory the release keeps is memory it was already keeping - so the call is accepted and says once that
// it did not do it, which is what an inert row promises. It is a hint to a cache this library does not run.
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
