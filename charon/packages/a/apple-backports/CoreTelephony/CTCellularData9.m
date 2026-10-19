#import <CoreTelephony/CTCellularData.h>
#import <CoreTelephony/CoreTelephonyDefines.h>
#import <dlfcn.h>

typedef void *CTServerConnectionRef;
typedef void (*CTServerConnectionCallback)(CTServerConnectionRef connection, CFStringRef notificationType, CFDictionaryRef notificationInfo, void *context);
typedef CTServerConnectionRef (*CharonCTServerConnectionCreate)(CFAllocatorRef allocator, CTServerConnectionCallback callback, void *context);
typedef CTError (*CharonCTServerConnectionGetCellularDataIsDisallowed)(CTServerConnectionRef connection, Boolean *disallowed);

static void *CharonCTHandle(void)
{
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
    });
    return handle;
}

// Measured on an iPhone 4S (6.1.3): CTServerConnectionCreate answers NULL whenever the callback
// argument is NULL, whatever the context is - a NULL callback is not tolerated, it is refused.
// A real (even inert) callback is what makes the daemon hand back a connection at all.
static void CharonCTServerConnectionNotified(CTServerConnectionRef connection, CFStringRef notificationType, CFDictionaryRef notificationInfo, void *context)
{
}

static CTServerConnectionRef CharonCTConnection(void)
{
    static CTServerConnectionRef connection;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CharonCTServerConnectionCreate create = (CharonCTServerConnectionCreate)dlsym(CharonCTHandle(), "_CTServerConnectionCreate");
        if (create)
            connection = create(NULL, CharonCTServerConnectionNotified, NULL);
    });
    return connection;
}

static BOOL CharonCTCellularDataIsDisallowed(BOOL *known)
{
    *known = NO;
    CTServerConnectionRef connection = CharonCTConnection();
    if (!connection)
        return NO;
    CharonCTServerConnectionGetCellularDataIsDisallowed get = (CharonCTServerConnectionGetCellularDataIsDisallowed)dlsym(CharonCTHandle(), "_CTServerConnectionGetCellularDataIsDisallowed");
    if (!get)
        return NO;
    Boolean disallowed = false;
    CTError error = get(connection, &disallowed);
    if (error.domain != kCTErrorDomainNoError)
        return NO;
    *known = YES;
    return disallowed;
}

static void CharonCTCellularDataChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@interface CTCellularData (CharonPrivate)
- (void)charon_checkForChange;
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
    BOOL disallowed = CharonCTCellularDataIsDisallowed(&known);
    if (!known)
        return kCTCellularDataRestrictedStateUnknown;
    return disallowed ? kCTCellularDataRestricted : kCTCellularDataNotRestricted;
}

- (void)charon_checkForChange
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
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, CharonCTCellularDataChanged,
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

static void CharonCTCellularDataChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    CTCellularData *data = (__bridge CTCellularData *)observer;
    [data charon_checkForChange];
}
