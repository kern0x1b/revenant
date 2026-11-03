#import <UIKit/UIKit.h>

BOOL hid_ready(void);
void hid_touch(int phase, CGPoint point);
BOOL hid_press(uint32_t usage_page, uint32_t usage);
