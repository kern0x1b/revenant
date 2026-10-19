#import <UIKit/UIKit.h>

@class UIDocumentPickerViewController;

@interface UIDocumentPickerViewController (CharonBrowser)
- (BOOL)charon_acceptsPath:(NSString *)path;
- (BOOL)charon_showsExtensions;
- (BOOL)charon_choosesFiles;
- (BOOL)charon_allowsMultiple;
- (void)charon_cancel;
- (void)charon_pickPaths:(NSArray<NSString *> *)paths;
- (void)charon_chooseFolder:(NSString *)path;
- (NSArray<NSDictionary *> *)charon_locations;
- (NSString *)charon_startFolder;
- (UIBarButtonItem *)charon_cancelItem;
- (NSString *)charon_destinationTitle;
@end

@interface CharonFileFolderController : UITableViewController
- (instancetype)initWithPath:(NSString *)path title:(NSString *)title picker:(UIDocumentPickerViewController *)picker;
@end

@interface CharonFileLocationsController : UITableViewController
- (instancetype)initWithPicker:(UIDocumentPickerViewController *)picker;
@end
