#import <UIKit/UIKit.h>

@class UIDocumentPickerViewController;

@interface UIDocumentPickerViewController (RevenantBrowser)
- (BOOL)revenant_acceptsPath:(NSString *)path;
- (BOOL)revenant_showsExtensions;
- (BOOL)revenant_choosesFiles;
- (BOOL)revenant_allowsMultiple;
- (void)revenant_cancel;
- (void)revenant_pickPaths:(NSArray<NSString *> *)paths;
- (void)revenant_chooseFolder:(NSString *)path;
- (NSArray<NSDictionary *> *)revenant_locations;
- (NSString *)revenant_startFolder;
- (UIBarButtonItem *)revenant_cancelItem;
- (NSString *)revenant_destinationTitle;
@end

@interface RevenantFileFolderController : UITableViewController
- (instancetype)initWithPath:(NSString *)path title:(NSString *)title picker:(UIDocumentPickerViewController *)picker;
@end

@interface RevenantFileLocationsController : UITableViewController
- (instancetype)initWithPicker:(UIDocumentPickerViewController *)picker;
@end
