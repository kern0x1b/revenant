#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <stdlib.h>

void (^const NSDataDeallocatorVM)(void *bytes, NSUInteger length) = ^(void *bytes, NSUInteger length) {
    vm_deallocate(mach_task_self(), (vm_address_t)bytes, length);
};

void (^const NSDataDeallocatorUnmap)(void *bytes, NSUInteger length) = ^(void *bytes, NSUInteger length) {
    munmap(bytes, length);
};

void (^const NSDataDeallocatorFree)(void *bytes, NSUInteger length) = ^(void *bytes, NSUInteger length) {
    free(bytes);
};

void (^const NSDataDeallocatorNone)(void *bytes, NSUInteger length) = NULL;
