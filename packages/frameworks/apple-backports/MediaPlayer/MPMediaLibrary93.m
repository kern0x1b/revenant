#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
typedef NSInteger MPMediaLibraryAuthorizationStatus;
enum { MPMediaLibraryAuthorizationStatusNotDetermined = 0, MPMediaLibraryAuthorizationStatusDenied = 1,
       MPMediaLibraryAuthorizationStatusRestricted = 2, MPMediaLibraryAuthorizationStatusAuthorized = 3 };
@interface MPMediaLibrary : NSObject
+ (MPMediaLibrary *)defaultMediaLibrary;
@end
@interface MPMediaLibrary (Revenant93)
+ (MPMediaLibraryAuthorizationStatus)authorizationStatus;
+ (void)requestAuthorization:(void (^)(MPMediaLibraryAuthorizationStatus status))completionHandler;
@end
#endif

@implementation MPMediaLibrary (Revenant93)

+ (MPMediaLibraryAuthorizationStatus)authorizationStatus {
    return MPMediaLibraryAuthorizationStatusAuthorized;
}

+ (void)requestAuthorization:(void (^)(MPMediaLibraryAuthorizationStatus status))completionHandler {
    if (completionHandler) {
        completionHandler(MPMediaLibraryAuthorizationStatusAuthorized);
    }
}

@end
