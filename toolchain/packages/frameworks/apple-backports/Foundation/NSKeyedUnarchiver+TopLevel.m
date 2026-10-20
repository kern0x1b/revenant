#import <Foundation/Foundation.h>

NSError *revenant_coder_error(NSException *exception, NSInteger code);

@implementation NSKeyedUnarchiver (RevenantTopLevel)

+ (id)unarchiveTopLevelObjectWithData:(NSData *)data error:(NSError **)error
{
    NSKeyedUnarchiver *unarchiver = nil;
    @try {
        unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    } @catch (NSException *exception) {
        return nil;
    }
    id decoded = nil;
    @try {
        decoded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        [unarchiver finishDecoding];
    } @catch (NSException *exception) {
        if (error)
            *error = revenant_coder_error(exception, NSCoderReadCorruptError);
        return nil;
    }
    return decoded;
}

@end
