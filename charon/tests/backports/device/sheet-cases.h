#import <UIKit/UIKit.h>

typedef void (^SheetRecorder)(NSString *name, NSString *value);

/* The detent and sheet API, which the host's UIKit answers: every record is compared. */
void sheet_api_run(SheetRecorder record);

/* The layout of a sheet in an iPhone-sized window (a phone, or an iPhone application on
   the iPad): the host shows a sheet in a window of its own and is no oracle for it, so
   device/sheet.m holds these records to the values read from UIKitCore of the 16.0 cache. */
void sheet_layout_run(UIWindow *window, SheetRecorder record, void (^done)(void));
