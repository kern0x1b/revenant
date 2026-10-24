#import "../Foundation/check.h"
#import <CoreText/CoreText.h>
#include <dlfcn.h>

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    const CFStringRef *tag = (const CFStringRef *)dlsym(RTLD_NEXT, "kCTFontOpenTypeFeatureTag");
    const CFStringRef *value = (const CFStringRef *)dlsym(RTLD_NEXT, "kCTFontOpenTypeFeatureValue");
    BOOL tagMatches = tag && kCTFontOpenTypeFeatureTag && CFEqual(kCTFontOpenTypeFeatureTag, *tag);
    BOOL valueMatches = value && kCTFontOpenTypeFeatureValue && CFEqual(kCTFontOpenTypeFeatureValue, *value);
    revenant_check(tagMatches && !revenant_negative, "the feature tag key matches CoreText", @"different feature tag key");
    revenant_check(valueMatches && !revenant_negative, "the feature value key matches CoreText", @"different feature value key");
    revenant_check(tag && value && !revenant_negative, "CoreText exports both feature keys", @"missing host exports");
    return revenant_finish();
}
