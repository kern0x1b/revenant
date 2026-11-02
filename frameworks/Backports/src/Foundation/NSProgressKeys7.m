#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

NSProgressUserInfoKey const BACKPORT_IMPL(NSProgressThroughputKey) = @"NSProgressThroughputKey";
NSProgressKind const BACKPORT_IMPL(NSProgressKindFile) = @"NSProgressKindFile";
NSProgressUserInfoKey const BACKPORT_IMPL(NSProgressFileOperationKindKey) = @"NSProgressFileOperationKindKey";
NSProgressFileOperationKind const BACKPORT_IMPL(NSProgressFileOperationKindDownloading) = @"NSProgressFileOperationKindDownloading";
NSProgressFileOperationKind const BACKPORT_IMPL(NSProgressFileOperationKindDecompressingAfterDownloading) = @"NSProgressFileOperationKindDecompressingAfterDownloading";
NSProgressFileOperationKind const BACKPORT_IMPL(NSProgressFileOperationKindCopying) = @"NSProgressFileOperationKindCopying";
NSProgressUserInfoKey const BACKPORT_IMPL(NSProgressFileURLKey) = @"NSProgressFileURLKey";
NSProgressUserInfoKey const BACKPORT_IMPL(NSProgressFileTotalCountKey) = @"NSProgressFileTotalCountKey";
NSProgressUserInfoKey const BACKPORT_IMPL(NSProgressFileCompletedCountKey) = @"NSProgressFileCompletedCountKey";
