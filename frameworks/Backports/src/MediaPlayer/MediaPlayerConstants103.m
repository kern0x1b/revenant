#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const MPMusicPlayerControllerQueueDidChangeNotification;

NSString *const BACKPORT_IMPL(MPMusicPlayerControllerQueueDidChangeNotification) = @"MPMusicPlayerControllerQueueDidChangeNotification";
