#import <CoreTelephony/CTCellularData.h>
#import <CoreTelephony/CoreTelephonyDefines.h>
#import <dlfcn.h>

typedef void *CTServerConnectionRef;
typedef void (*CTServerConnectionCallback)(CTServerConnectionRef connection, CFStringRef notificationType, CFDictionaryRef notificationInfo, void *context);
typedef CTServerConnectionRef (*RevenantCTServerConnectionCreate)(CFAllocatorRef allocator, CTServerConnectionCallback callback, void *context);
typedef CTError (*RevenantCTServerConnectionGetCellularDataIsDisallowed)(CTServerConnectionRef connection, Boolean *disallowed);

static void *RevenantCTHandle(void)
{
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
    });
    return handle;
}

static void RevenantCTServerConnectionNotified(CTServerConnectionRef connection, CFStringRef notificationType, CFDictionaryRef notificationInfo, void *context)
{
}

static CTServerConnectionRef RevenantCTConnection(void)
{
    static CTServerConnectionRef connection;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        RevenantCTServerConnectionCreate create = (RevenantCTServerConnectionCreate)dlsym(RevenantCTHandle(), "_CTServerConnectionCreate");
        if (create)
            connection = create(NULL, RevenantCTServerConnectionNotified, NULL);
    });
    return connection;
}

static BOOL RevenantCTCellularDataIsDisallowed(BOOL *known)
{
    *known = NO;
    CTServerConnectionRef connection = RevenantCTConnection();
    if (!connection)
        return NO;
    RevenantCTServerConnectionGetCellularDataIsDisallowed get = (RevenantCTServerConnectionGetCellularDataIsDisallowed)dlsym(RevenantCTHandle(), "_CTServerConnectionGetCellularDataIsDisallowed");
    if (!get)
        return NO;
    Boolean disallowed = false;
    CTError error = get(connection, &disallowed);
    if (error.domain != kCTErrorDomainNoError)
        return NO;
    *known = YES;
    return disallowed;
}

static void RevenantCTCellularDataChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@interface CTCellularData (RevenantPrivate)
- (void)revenant_checkForChange;
@end

@implementation CTCellularData
{
    CellularDataRestrictionDidUpdateNotifier _notifier;
    CTCellularDataRestrictedState _lastState;
    BOOL _observing;
}

- (CTCellularDataRestrictedState)restrictedState
{
    BOOL known = NO;
    BOOL disallowed = RevenantCTCellularDataIsDisallowed(&known);
    if (!known)
        return kCTCellularDataRestrictedStateUnknown;
    return disallowed ? kCTCellularDataRestricted : kCTCellularDataNotRestricted;
}

- (void)revenant_checkForChange
{
    CTCellularDataRestrictedState state = self.restrictedState;
    if (state == _lastState)
        return;
    _lastState = state;
    CellularDataRestrictionDidUpdateNotifier notifier = _notifier;
    if (notifier)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            notifier(state);
        });
}

- (CellularDataRestrictionDidUpdateNotifier)cellularDataRestrictionDidUpdateNotifier
{
    return _notifier;
}

- (void)setCellularDataRestrictionDidUpdateNotifier:(CellularDataRestrictionDidUpdateNotifier)notifier
{
    _notifier = [notifier copy];
    if (notifier && !_observing) {
        _observing = YES;
        _lastState = self.restrictedState;
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, RevenantCTCellularDataChanged,
                                         CFSTR("com.apple.coretelephony"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CTCellularDataRestrictedState initial = _lastState;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            notifier(initial);
        });
    } else if (!notifier && _observing) {
        _observing = NO;
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, CFSTR("com.apple.coretelephony"), NULL);
    }
}

- (void)dealloc
{
    if (_observing)
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, CFSTR("com.apple.coretelephony"), NULL);
}

@end

static void RevenantCTCellularDataChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    CTCellularData *data = (__bridge CTCellularData *)observer;
    [data revenant_checkForChange];
}
