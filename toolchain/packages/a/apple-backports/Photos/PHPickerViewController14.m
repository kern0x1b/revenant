#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PHPickerViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation PHPickerViewController {
    PHPickerConfiguration *_configuration;
    UIImagePickerController *_picker;
    BOOL _finished;
    __weak id<PHPickerViewControllerDelegate> _delegate;
}

- (instancetype)initWithConfiguration:(PHPickerConfiguration *)configuration
{
    if ((self = [super initWithNibName:nil bundle:nil]))
        _configuration = [configuration copy];
    return self;
}

- (PHPickerConfiguration *)configuration
{
    return [_configuration copy];
}

- (id<PHPickerViewControllerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<PHPickerViewControllerDelegate>)delegate
{
    _delegate = delegate;
}

- (NSArray<NSString *> *)charon_mediaTypes
{
    NSArray *wanted = _configuration.filter ? [_configuration.filter charon_mediaTypes] : @[@"public.image", @"public.movie"];
    NSArray *available = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    NSMutableArray *types = [NSMutableArray array];
    for (NSString *type in wanted)
        if ([available containsObject:type])
            [types addObject:type];
    return types;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSArray *types = [self charon_mediaTypes];
    if (!types.count)
        return;
    _picker = [[UIImagePickerController alloc] init];
    _picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    _picker.mediaTypes = types;
    _picker.allowsEditing = NO;
    _picker.delegate = self;
    [self addChildViewController:_picker];
    _picker.view.frame = self.view.bounds;
    _picker.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_picker.view];
    [_picker didMoveToParentViewController:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!_picker)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self charon_finishWithResults:@[]];
        });
}

- (void)charon_finishWithResults:(NSArray<PHPickerResult *> *)results
{
    if (_finished)
        return;
    _finished = YES;
    id<PHPickerViewControllerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(picker:didFinishPicking:)])
        [delegate picker:self didFinishPicking:results];
}

- (NSString *)charon_typeOfReferenceURL:(NSURL *)URL
{
    for (NSString *pair in [[URL query] componentsSeparatedByString:@"&"]) {
        if (![pair hasPrefix:@"ext="])
            continue;
        NSString *extension = [[pair substringFromIndex:4] uppercaseString];
        if ([extension isEqualToString:@"PNG"])
            return @"public.png";
        if ([extension isEqualToString:@"GIF"])
            return @"com.compuserve.gif";
        if ([extension isEqualToString:@"TIF"] || [extension isEqualToString:@"TIFF"])
            return @"public.tiff";
    }
    return @"public.jpeg";
}

- (NSItemProvider *)charon_providerForInfo:(NSDictionary *)info
{
    NSItemProvider *provider = [[NSItemProvider alloc] init];
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:@"public.movie"]) {
        NSURL *URL = info[UIImagePickerControllerMediaURL];
        if (!URL)
            return nil;
        NSString *extension = [[URL pathExtension] lowercaseString];
        NSString *type = [extension isEqualToString:@"mov"] ? @"com.apple.quicktime-movie" : ([extension isEqualToString:@"mp4"] || [extension isEqualToString:@"m4v"]) ? @"public.mpeg-4" : @"public.movie";
        [provider registerFileRepresentationForTypeIdentifier:type fileOptions:0 visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^completion)(NSURL *, BOOL, NSError *)) {
            completion(URL, NO, nil);
            return nil;
        }];
        provider.suggestedName = [[URL lastPathComponent] stringByDeletingPathExtension];
        return provider;
    }
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (!image)
        return nil;
    NSString *type = [self charon_typeOfReferenceURL:info[UIImagePickerControllerReferenceURL]];
    [provider registerDataRepresentationForTypeIdentifier:type visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^completion)(NSData *, NSError *)) {
        NSData *data = [type isEqualToString:@"public.png"] ? UIImagePNGRepresentation(image) : UIImageJPEGRepresentation(image, 1.0);
        completion(data, data ? nil : [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil]);
        return nil;
    }];
    return provider;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSItemProvider *provider = [self charon_providerForInfo:info];
    NSArray *results = provider ? @[[[PHPickerResult alloc] initWithCharonItemProvider:provider]] : @[];
    [self charon_finishWithResults:results];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self charon_finishWithResults:@[]];
}

@end
