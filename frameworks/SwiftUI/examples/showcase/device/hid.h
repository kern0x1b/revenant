#import <UIKit/UIKit.h>

// Digitizer touches injected through IOKit's HID event system. The demo's gesture
// driver and the guest revenant-unlock tool both send touches through this one path.
BOOL hid_ready(void);
void hid_touch(int phase, CGPoint point);
