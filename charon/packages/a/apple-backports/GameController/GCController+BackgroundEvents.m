#import <GameController/GameController.h>

static BOOL gMonitorBackgroundEvents;

@implementation GCController (CharonBackgroundEvents)

+ (BOOL)shouldMonitorBackgroundEvents
{
    return gMonitorBackgroundEvents;
}

+ (void)setShouldMonitorBackgroundEvents:(BOOL)value
{
    gMonitorBackgroundEvents = value;
}

@end
