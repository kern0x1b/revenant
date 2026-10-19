#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <ImageIO/ImageIO.h>
#import <objc/message.h>
#import <Photos/PHError.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RevenantPhotosStore : NSObject
+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason;
+ (NSString *)writeImageData:(NSData *)data metadata:(NSDictionary *)metadata error:(NSError **)error;
+ (NSString *)writeImage:(UIImage *)image error:(NSError **)error;
+ (NSString *)writeVideoAtURL:(NSURL *)url error:(NSError **)error;
+ (void)bindPlaceholderIdentifier:(NSString *)token toIdentifier:(NSString *)identifier;
@end

@interface RevenantPhotosTransaction : NSObject
+ (RevenantPhotosTransaction *)current;
- (void)addChange:(id)change;
- (void)refuseWithReason:(NSString *)reason;
@end

@interface PHObjectPlaceholder : NSObject
- (instancetype)initWithRevenantLocalIdentifier:(NSString *)identifier;
@end

typedef NS_ENUM(NSInteger, RevenantChangeKind) {
    RevenantChangeImage,
    RevenantChangeImageFile,
    RevenantChangeVideoFile,
    RevenantChangeEdit
};

@interface PHAssetChangeRequest : NSObject
+ (instancetype)creationRequestForAssetFromImage:(UIImage *)image;
+ (instancetype)creationRequestForAssetFromImageAtFileURL:(NSURL *)fileURL;
+ (instancetype)creationRequestForAssetFromVideoAtFileURL:(NSURL *)fileURL;
+ (void)deleteAssets:(id<NSFastEnumeration>)assets;
+ (instancetype)changeRequestForAsset:(id)asset;
@property (nonatomic, strong, readonly) PHObjectPlaceholder *placeholderForCreatedAsset;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) CLLocation *location;
@property (nonatomic, assign, getter=isFavorite) BOOL favorite;
@property (nonatomic, assign, getter=isHidden) BOOL hidden;
@end

static RevenantPhotosTransaction *revenant_transaction(void)
{
    RevenantPhotosTransaction *transaction = [RevenantPhotosTransaction current];
    if (!transaction)
        [NSException raise:NSInternalInconsistencyException format:@"This method can only be called from inside of -[PHPhotoLibrary performChanges:completionHandler:] or -[PHPhotoLibrary performChangesAndWait:error:]"];
    return transaction;
}

@implementation PHAssetChangeRequest {
    RevenantChangeKind _kind;
    id _source;
    NSString *_token;
    PHObjectPlaceholder *_placeholder;
    NSDate *_creationDate;
    CLLocation *_location;
    BOOL _favorite;
    BOOL _hidden;
}

+ (instancetype)revenant_requestOfKind:(RevenantChangeKind)kind source:(id)source
{
    RevenantPhotosTransaction *transaction = revenant_transaction();
    PHAssetChangeRequest *request = [[self alloc] init];
    request->_kind = kind;
    request->_source = source;
    if (kind != RevenantChangeEdit) {
        request->_token = [[NSUUID UUID].UUIDString stringByAppendingString:@"/L0/001"];
        request->_placeholder = [[PHObjectPlaceholder alloc] initWithRevenantLocalIdentifier:request->_token];
    }
    [transaction addChange:request];
    return request;
}

+ (instancetype)creationRequestForAssetFromImage:(UIImage *)image
{
    return [self revenant_requestOfKind:RevenantChangeImage source:image];
}

+ (instancetype)creationRequestForAssetFromImageAtFileURL:(NSURL *)fileURL
{
    revenant_transaction();
    if (!fileURL.isFileURL || ![UIImage imageWithContentsOfFile:fileURL.path])
        return nil;
    return [self revenant_requestOfKind:RevenantChangeImageFile source:fileURL];
}

+ (instancetype)creationRequestForAssetFromVideoAtFileURL:(NSURL *)fileURL
{
    revenant_transaction();
    if (!fileURL.isFileURL || !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL.path))
        return nil;
    return [self revenant_requestOfKind:RevenantChangeVideoFile source:fileURL];
}

+ (void)deleteAssets:(id<NSFastEnumeration>)assets
{
    [revenant_transaction() refuseWithReason:@"iOS 6 lets an application add to the photo library and read it, not delete from it"];
}

+ (instancetype)changeRequestForAsset:(id)asset
{
    return [self revenant_requestOfKind:RevenantChangeEdit source:asset];
}

- (PHObjectPlaceholder *)placeholderForCreatedAsset
{
    return _placeholder;
}

- (NSDate *)creationDate
{
    return _creationDate;
}

- (void)setCreationDate:(NSDate *)date
{
    _creationDate = date;
    if (_kind == RevenantChangeEdit)
        [revenant_transaction() refuseWithReason:@"iOS 6 does not let an application change the date of an asset that is in the photo library"];
}

- (CLLocation *)location
{
    return _location;
}

- (void)setLocation:(CLLocation *)location
{
    _location = location;
    if (_kind == RevenantChangeEdit)
        [revenant_transaction() refuseWithReason:@"iOS 6 does not let an application change the location of an asset that is in the photo library"];
}

- (BOOL)isFavorite
{
    return _favorite;
}

- (void)setFavorite:(BOOL)favorite
{
    _favorite = favorite;
    if (favorite || _kind == RevenantChangeEdit)
        [revenant_transaction() refuseWithReason:@"iOS 6 has no favorites"];
}

- (BOOL)isHidden
{
    return _hidden;
}

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
    if (hidden || _kind == RevenantChangeEdit)
        [revenant_transaction() refuseWithReason:@"iOS 6 cannot hide an asset"];
}

- (NSDictionary *)revenant_metadata
{
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    if (_creationDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
        NSString *text = [formatter stringFromDate:_creationDate];
        metadata[(__bridge NSString *)kCGImagePropertyExifDictionary] = @{(__bridge NSString *)kCGImagePropertyExifDateTimeOriginal: text,
                                                                          (__bridge NSString *)kCGImagePropertyExifDateTimeDigitized: text};
        metadata[(__bridge NSString *)kCGImagePropertyTIFFDictionary] = @{(__bridge NSString *)kCGImagePropertyTIFFDateTime: text};
    }
    if (_location) {
        CLLocationCoordinate2D coordinate = _location.coordinate;
        NSDateFormatter *stamp = [[NSDateFormatter alloc] init];
        stamp.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        stamp.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        stamp.dateFormat = @"HH:mm:ss.SS";
        NSString *time = [stamp stringFromDate:_location.timestamp ?: [NSDate date]];
        stamp.dateFormat = @"yyyy:MM:dd";
        NSString *day = [stamp stringFromDate:_location.timestamp ?: [NSDate date]];
        metadata[(__bridge NSString *)kCGImagePropertyGPSDictionary] = @{
            (__bridge NSString *)kCGImagePropertyGPSLatitude: @(fabs(coordinate.latitude)),
            (__bridge NSString *)kCGImagePropertyGPSLatitudeRef: coordinate.latitude < 0 ? @"S" : @"N",
            (__bridge NSString *)kCGImagePropertyGPSLongitude: @(fabs(coordinate.longitude)),
            (__bridge NSString *)kCGImagePropertyGPSLongitudeRef: coordinate.longitude < 0 ? @"W" : @"E",
            (__bridge NSString *)kCGImagePropertyGPSAltitude: @(fabs(_location.altitude)),
            (__bridge NSString *)kCGImagePropertyGPSAltitudeRef: @(_location.altitude < 0 ? 1 : 0),
            (__bridge NSString *)kCGImagePropertyGPSTimeStamp: time,
            (__bridge NSString *)kCGImagePropertyGPSDateStamp: day};
    }
    return metadata.count ? metadata : nil;
}

- (BOOL)revenant_validate:(NSError **)error
{
    if (_kind == RevenantChangeImage && [_source CGImage] == NULL) {
        if (error)
            *error = [RevenantPhotosStore errorWithCode:PHPhotosErrorInvalidResource reason:@"the image has no pixels to add"];
        return NO;
    }
    return YES;
}

- (BOOL)revenant_commit:(NSError **)error
{
    NSDictionary *metadata = [self revenant_metadata];
    NSString *identifier = nil;
    switch (_kind) {
    case RevenantChangeImage:
        if (metadata) {
            NSData *data = UIImageJPEGRepresentation(_source, 1);
            identifier = [RevenantPhotosStore writeImageData:data metadata:metadata error:error];
        } else {
            identifier = [RevenantPhotosStore writeImage:_source error:error];
        }
        break;
    case RevenantChangeImageFile:
        identifier = [RevenantPhotosStore writeImageData:[NSData dataWithContentsOfURL:_source] metadata:metadata error:error];
        break;
    case RevenantChangeVideoFile:
        identifier = [RevenantPhotosStore writeVideoAtURL:_source error:error];
        break;
    case RevenantChangeEdit:
        return YES;
    }
    if (!identifier)
        return NO;
    [RevenantPhotosStore bindPlaceholderIdentifier:_token toIdentifier:identifier];
    return YES;
}

@end
