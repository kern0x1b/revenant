#import <GameController/GameController.h>

static BOOL gMonitorBackgroundEvents;

@implementation GCController (RevenantBackgroundEvents)

+ (BOOL)shouldMonitorBackgroundEvents
{
    return gMonitorBackgroundEvents;
}

+ (void)setShouldMonitorBackgroundEvents:(BOOL)value
{
    gMonitorBackgroundEvents = value;
}

@end
