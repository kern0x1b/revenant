#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, UIBackgroundFetchResult) {
    UIBackgroundFetchResultNewData = 0,
    UIBackgroundFetchResultNoData = 1,
    UIBackgroundFetchResultFailed = 2,
};

const char *revenant_background_fetch_result_name(UIBackgroundFetchResult result)
{
    switch (result) {
        case UIBackgroundFetchResultNewData: return "UIBackgroundFetchResultNewData";
        case UIBackgroundFetchResultNoData: return "UIBackgroundFetchResultNoData";
        case UIBackgroundFetchResultFailed: return "UIBackgroundFetchResultFailed";
        default: return "UIBackgroundFetchResultUnknown";
    }
}