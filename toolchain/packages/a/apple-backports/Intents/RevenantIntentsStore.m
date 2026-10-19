#import "RevenantIntentsStore.h"

#import <Intents/Intents.h>

static NSString *const RevenantIntentsErrorDomain = @"org.revenant.intents.store";

enum {
    RevenantIntentsErrorCannotCreate = 1,
    RevenantIntentsErrorCannotWrite,
    RevenantIntentsErrorCannotRead,
    RevenantIntentsErrorCannotDecode,
};

static dispatch_queue_t revenant_intents_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("org.revenant.intents.store", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

NSString *revenant_intents_store_directory(void)
{
    static NSString *directory;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                             NSUserDomainMask, YES);
        NSString *base = paths.count ? paths[0] : NSTemporaryDirectory();
        directory = [base stringByAppendingPathComponent:@"Revenant/Intents"];
    });
    return directory;
}

static NSString *revenant_intents_file(NSString *name)
{
    return [revenant_intents_store_directory() stringByAppendingPathComponent:name];
}

static NSError *revenant_intents_error(NSInteger code, NSString *path, NSError *cause)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"the Intents store could not use %@", path];
    info[NSFilePathErrorKey] = path;
    if (cause) {
        info[NSUnderlyingErrorKey] = cause;
    }
    return [NSError errorWithDomain:RevenantIntentsErrorDomain code:code userInfo:info];
}

static BOOL revenant_intents_prepare(NSError **error)
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *directory = revenant_intents_store_directory();
    if ([files fileExistsAtPath:directory]) {
        return YES;
    }
    NSError *failure = nil;
    if ([files createDirectoryAtPath:directory withIntermediateDirectories:YES
          attributes:nil error:&failure]) {
        return YES;
    }
    if (error) {
        *error = revenant_intents_error(RevenantIntentsErrorCannotCreate, directory, failure);
    }
    return NO;
}

static BOOL revenant_intents_write(NSString *path, id contents, NSError **error)
{
    if (!revenant_intents_prepare(error)) {
        return NO;
    }
    NSError *failure = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:contents
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&failure];
    if (!data || ![data writeToFile:path atomically:YES]) {
        if (error) {
            *error = revenant_intents_error(RevenantIntentsErrorCannotWrite, path, failure);
        }
        return NO;
    }
    return YES;
}

static id revenant_intents_contents(NSString *path, NSError **error, Class wanted)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if (error) {
            *error = revenant_intents_error(RevenantIntentsErrorCannotRead, path, nil);
        }
        return nil;
    }
    NSError *failure = nil;
    id contents = [NSPropertyListSerialization propertyListWithData:data
                                                             options:NSPropertyListImmutable
                                                              format:NULL
                                                               error:&failure];
    if (![contents isKindOfClass:wanted]) {
        if (error) {
            *error = revenant_intents_error(RevenantIntentsErrorCannotDecode, path, failure);
        }
        return nil;
    }
    return contents;
}

#pragma mark - The interaction store

static NSString *revenant_intents_interactions_file(void)
{
    return revenant_intents_file(@"Interactions.plist");
}

static NSMutableArray *revenant_intents_stored_archives(NSError **error)
{
    NSMutableArray *archives = [NSMutableArray array];
    id contents = revenant_intents_contents(revenant_intents_interactions_file(), error, [NSArray class]);
    for (id entry in contents) {
        if ([entry isKindOfClass:[NSData class]]) {
            [archives addObject:entry];
        }
    }
    return archives;
}

static BOOL revenant_intents_write_archives(NSArray *archives, NSError **error)
{
    return revenant_intents_write(revenant_intents_interactions_file(), archives, error);
}

NSArray *revenant_intents_stored_interactions(NSString *groupIdentifier)
{
    __block NSArray *found;
    dispatch_sync(revenant_intents_queue(), ^{
        NSMutableArray *interactions = [NSMutableArray array];
        for (NSData *archive in revenant_intents_stored_archives(NULL)) {
            INInteraction *interaction = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
            if (!interaction) {
                continue;
            }
            if (groupIdentifier && ![groupIdentifier isEqualToString:interaction.groupIdentifier]) {
                continue;
            }
            [interactions addObject:interaction];
        }
        found = [interactions copy];
    });
    return found;
}

NSError *revenant_intents_store_interaction(INInteraction *interaction)
{
    __block NSError *reported = nil;
    dispatch_sync(revenant_intents_queue(), ^{
        NSError *failure = nil;
        NSMutableArray *archives = revenant_intents_stored_archives(&failure);
        if (failure) {
            reported = failure;
            return;
        }
        NSError *archiveFailure = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:interaction
                                                requiringSecureCoding:YES
                                                                error:&archiveFailure];
        if (!archive) {
            reported = revenant_intents_error(RevenantIntentsErrorCannotDecode,
                                            revenant_intents_interactions_file(), archiveFailure);
            return;
        }
        [archives addObject:archive];
        if (!revenant_intents_write_archives(archives, &failure)) {
            reported = failure;
        }
    });
    return reported;
}

NSError *revenant_intents_delete_interactions(NSArray *identifiers, NSString *groupIdentifier)
{
    __block NSError *reported = nil;
    dispatch_sync(revenant_intents_queue(), ^{
        NSError *failure = nil;
        NSMutableArray *archives = revenant_intents_stored_archives(&failure);
        if (failure) {
            reported = failure;
            return;
        }
        if (!identifiers && !groupIdentifier) {
            reported = revenant_intents_write_archives([NSArray array], &failure) ? nil : failure;
            return;
        }
        NSSet *wanted = identifiers.count ? [NSSet setWithArray:identifiers] : nil;
        NSMutableArray *kept = [NSMutableArray arrayWithCapacity:archives.count];
        for (NSData *archive in archives) {
            INInteraction *interaction = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
            if (wanted && interaction && [wanted containsObject:interaction.identifier]) {
                continue;
            }
            if (groupIdentifier && interaction &&
                [groupIdentifier isEqualToString:interaction.groupIdentifier]) {
                continue;
            }
            [kept addObject:archive];
        }
        if (!revenant_intents_write_archives(kept, &failure)) {
            reported = failure;
        }
    });
    return reported;
}

#pragma mark - The vocabulary store

static NSString *revenant_intents_vocabulary_file(void)
{
    return revenant_intents_file(@"Vocabulary.plist");
}

static NSMutableDictionary *revenant_intents_stored_vocabulary(NSError **error)
{
    NSMutableDictionary *stored = [NSMutableDictionary dictionary];
    id contents = revenant_intents_contents(revenant_intents_vocabulary_file(), error, [NSDictionary class]);
    for (id key in contents) {
        id value = contents[key];
        if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSArray class]]) {
            stored[key] = value;
        }
    }
    return stored;
}

NSOrderedSet *revenant_intents_vocabulary(NSInteger type)
{
    __block NSOrderedSet *found;
    dispatch_sync(revenant_intents_queue(), ^{
        id phrases = revenant_intents_stored_vocabulary(NULL)[@(type)];
        found = [NSOrderedSet orderedSetWithArray:phrases ?: [NSArray array]];
    });
    return found;
}

void revenant_intents_store_vocabulary(NSInteger type, NSArray *phrases)
{
    dispatch_sync(revenant_intents_queue(), ^{
        NSMutableDictionary *stored = revenant_intents_stored_vocabulary(NULL);
        stored[@(type)] = [phrases copy] ?: [NSArray array];
        revenant_intents_write(revenant_intents_vocabulary_file(), stored, NULL);
    });
}

void revenant_intents_remove_vocabulary(void)
{
    dispatch_sync(revenant_intents_queue(), ^{
        revenant_intents_write(revenant_intents_vocabulary_file(), [NSDictionary dictionary], NULL);
    });
}
