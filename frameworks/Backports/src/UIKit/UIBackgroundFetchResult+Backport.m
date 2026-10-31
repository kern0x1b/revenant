#import <UIKit/UIKit.h>

const char *revenant_background_fetch_result_name(UIBackgroundFetchResult result)
{
    switch (result) {
        case UIBackgroundFetchResultNewData: return "UIBackgroundFetchResultNewData";
        case UIBackgroundFetchResultNoData: return "UIBackgroundFetchResultNoData";
        case UIBackgroundFetchResultFailed: return "UIBackgroundFetchResultFailed";
        default: return "UIBackgroundFetchResultUnknown";
    }
}