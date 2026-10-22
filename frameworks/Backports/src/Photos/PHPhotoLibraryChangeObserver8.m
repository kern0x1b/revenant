#import <Foundation/Foundation.h>

@class PHChange;

@protocol PHPhotoLibraryChangeObserver <NSObject>
- (void)photoLibraryDidChange:(PHChange *)changeInstance;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(PHPhotoLibraryChangeObserver);
}
