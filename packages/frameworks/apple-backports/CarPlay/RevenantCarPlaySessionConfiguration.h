#ifndef REVENANT_CARPLAY_SESSION_CONFIGURATION_H
#define REVENANT_CARPLAY_SESSION_CONFIGURATION_H

#import <CarPlay/CarPlay.h>

@interface CPSessionConfiguration (RevenantContentStyle)

- (CPContentStyle)revenant_contentStyle;

@end

#endif
