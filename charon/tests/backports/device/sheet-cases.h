#import <UIKit/UIKit.h>

typedef void (^SheetRecorder)(NSString *name, NSString *value);

void sheet_api_run(SheetRecorder record);

void sheet_layout_run(UIWindow *window, SheetRecorder record, void (^done)(void));
