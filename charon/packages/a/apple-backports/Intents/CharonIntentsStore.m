//
//  CharonIntentsStore.m
//  Intents
//
//  The two stores CharonIntentsStore.h declares. Every write is a real file under this
//  application's own Application Support, read back through the same path, and every failure is
//  the error the file system reported rather than a nil that means nothing.
//

#import "CharonIntentsStore.h"

#import <Intents/Intents.h>

static NSString *const CharonIntentsErrorDomain = @"org.charon.intents.store";

enum {
    CharonIntentsErrorCannotCreate = 1,
    CharonIntentsErrorCannotWrite,
    CharonIntentsErrorCannotRead,
    CharonIntentsErrorCannotDecode,
};

// One queue for both stores: a donation and a vocabulary write from two threads must not
// interleave a read and a rewrite of the same file.
static dispatch_queue_t charon_intents_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("org.charon.intents.store", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

NSString *charon_intents_store_directory(void)
{
    static NSString *directory;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                             NSUserDomainMask, YES);
        NSString *base = paths.count ? paths[0] : NSTemporaryDirectory();
        directory = [base stringByAppendingPathComponent:@"Charon/Intents"];
    });
    return directory;
}

static NSString *charon_intents_file(NSString *name)
{
    return [charon_intents_store_directory() stringByAppendingPathComponent:name];
}

static NSError *charon_intents_error(NSInteger code, NSString *path, NSError *cause)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"the Intents store could not use %@", path];
    info[NSFilePathErrorKey] = path;
    if (cause) {
        info[NSUnderlyingErrorKey] = cause;
    }
    return [NSError errorWithDomain:CharonIntentsErrorDomain code:code userInfo:info];
}

static BOOL charon_intents_prepare(NSError **error)
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *directory = charon_intents_store_directory();
    if ([files fileExistsAtPath:directory]) {
        return YES;
    }
    NSError *failure = nil;
    if ([files createDirectoryAtPath:directory withIntermediateDirectories:YES
          attributes:nil error:&failure]) {
        return YES;
    }
    if (error) {
        *error = charon_intents_error(CharonIntentsErrorCannotCreate, directory, failure);
    }
    return NO;
}

static BOOL charon_intents_write(NSString *path, id contents, NSError **error)
{
    if (!charon_intents_prepare(error)) {
        return NO;
    }
    NSError *failure = nil;
    // The stores are property lists, written through the serialisation of their own class rather
    // than through -writeToFile:atomically:, which this release's Foundation has no error
    // reporting form of, so a failed write is the serialisation's own error and not a silent nil.
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:contents
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&failure];
    if (!data || ![data writeToFile:path atomically:YES]) {
        if (error) {
            *error = charon_intents_error(CharonIntentsErrorCannotWrite, path, failure);
        }
        return NO;
    }
    return YES;
}

static id charon_intents_contents(NSString *path, NSError **error, Class wanted)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if (error) {
            *error = charon_intents_error(CharonIntentsErrorCannotRead, path, nil);
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
            *error = charon_intents_error(CharonIntentsErrorCannotDecode, path, failure);
        }
        return nil;
    }
    return contents;
}

#pragma mark - The interaction store

static NSString *charon_intents_interactions_file(void)
{
    return charon_intents_file(@"Interactions.plist");
}

// The stored interactions as their archives, so a delete can drop one without decoding it and a
// donation can append one without decoding the rest.
static NSMutableArray *charon_intents_stored_archives(NSError **error)
{
    NSMutableArray *archives = [NSMutableArray array];
    id contents = charon_intents_contents(charon_intents_interactions_file(), error, [NSArray class]);
    for (id entry in contents) {
        if ([entry isKindOfClass:[NSData class]]) {
            [archives addObject:entry];
        }
    }
    return archives;
}

static BOOL charon_intents_write_archives(NSArray *archives, NSError **error)
{
    return charon_intents_write(charon_intents_interactions_file(), archives, error);
}

NSArray *charon_intents_stored_interactions(NSString *groupIdentifier)
{
    __block NSArray *found;
    dispatch_sync(charon_intents_queue(), ^{
        NSMutableArray *interactions = [NSMutableArray array];
        for (NSData *archive in charon_intents_stored_archives(NULL)) {
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

NSError *charon_intents_store_interaction(INInteraction *interaction)
{
    __block NSError *reported = nil;
    dispatch_sync(charon_intents_queue(), ^{
        NSError *failure = nil;
        NSMutableArray *archives = charon_intents_stored_archives(&failure);
        if (failure) {
            reported = failure;
            return;
        }
        NSError *archiveFailure = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:interaction
                                                requiringSecureCoding:YES
                                                                error:&archiveFailure];
        if (!archive) {
            reported = charon_intents_error(CharonIntentsErrorCannotDecode,
                                            charon_intents_interactions_file(), archiveFailure);
            return;
        }
        [archives addObject:archive];
        if (!charon_intents_write_archives(archives, &failure)) {
            reported = failure;
        }
    });
    return reported;
}

NSError *charon_intents_delete_interactions(NSArray *identifiers, NSString *groupIdentifier)
{
    __block NSError *reported = nil;
    dispatch_sync(charon_intents_queue(), ^{
        NSError *failure = nil;
        NSMutableArray *archives = charon_intents_stored_archives(&failure);
        if (failure) {
            reported = failure;
            return;
        }
        if (!identifiers && !groupIdentifier) {
            reported = charon_intents_write_archives([NSArray array], &failure) ? nil : failure;
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
        if (!charon_intents_write_archives(kept, &failure)) {
            reported = failure;
        }
    });
    return reported;
}

#pragma mark - The vocabulary store

static NSString *charon_intents_vocabulary_file(void)
{
    return charon_intents_file(@"Vocabulary.plist");
}

static NSMutableDictionary *charon_intents_stored_vocabulary(NSError **error)
{
    NSMutableDictionary *stored = [NSMutableDictionary dictionary];
    id contents = charon_intents_contents(charon_intents_vocabulary_file(), error, [NSDictionary class]);
    for (id key in contents) {
        id value = contents[key];
        if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSArray class]]) {
            stored[key] = value;
        }
    }
    return stored;
}

NSOrderedSet *charon_intents_vocabulary(NSInteger type)
{
    __block NSOrderedSet *found;
    dispatch_sync(charon_intents_queue(), ^{
        id phrases = charon_intents_stored_vocabulary(NULL)[@(type)];
        found = [NSOrderedSet orderedSetWithArray:phrases ?: [NSArray array]];
    });
    return found;
}

void charon_intents_store_vocabulary(NSInteger type, NSArray *phrases)
{
    dispatch_sync(charon_intents_queue(), ^{
        NSMutableDictionary *stored = charon_intents_stored_vocabulary(NULL);
        stored[@(type)] = [phrases copy] ?: [NSArray array];
        charon_intents_write(charon_intents_vocabulary_file(), stored, NULL);
    });
}

void charon_intents_remove_vocabulary(void)
{
    dispatch_sync(charon_intents_queue(), ^{
        charon_intents_write(charon_intents_vocabulary_file(), [NSDictionary dictionary], NULL);
    });
}
