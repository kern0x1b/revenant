#import <Foundation/Foundation.h>

static inline NSData *_Nullable revenant_file_handle_read(NSFileHandle *_Nonnull handle, NSUInteger length, NSError *_Nullable *_Nullable error)
{
    return [handle readDataUpToLength:length error:error];
}

static inline BOOL revenant_file_handle_write(NSFileHandle *_Nonnull handle, NSData *_Nonnull data, NSError *_Nullable *_Nullable error)
{
    return [handle writeData:data error:error];
}

static inline BOOL revenant_file_handle_get_offset(NSFileHandle *_Nonnull handle, unsigned long long *_Nonnull offset, NSError *_Nullable *_Nullable error)
{
    return [handle getOffset:offset error:error];
}

static inline BOOL revenant_file_handle_seek_to_end(NSFileHandle *_Nonnull handle, unsigned long long *_Nullable offset, NSError *_Nullable *_Nullable error)
{
    return [handle seekToEndReturningOffset:offset error:error];
}

static inline BOOL revenant_file_handle_seek(NSFileHandle *_Nonnull handle, unsigned long long offset, NSError *_Nullable *_Nullable error)
{
    return [handle seekToOffset:offset error:error];
}

static inline BOOL revenant_file_handle_truncate(NSFileHandle *_Nonnull handle, unsigned long long offset, NSError *_Nullable *_Nullable error)
{
    return [handle truncateAtOffset:offset error:error];
}

static inline BOOL revenant_file_handle_synchronize(NSFileHandle *_Nonnull handle, NSError *_Nullable *_Nullable error)
{
    return [handle synchronizeAndReturnError:error];
}

static inline BOOL revenant_file_handle_close(NSFileHandle *_Nonnull handle, NSError *_Nullable *_Nullable error)
{
    return [handle closeAndReturnError:error];
}
