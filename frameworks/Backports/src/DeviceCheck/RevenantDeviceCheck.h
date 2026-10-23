#if defined(REVENANT_HOST_BUILD)
#define DCDevice DCDeviceRevenant
#define DCAppAttestService DCAppAttestServiceRevenant
#endif

#import <DeviceCheck/DeviceCheck.h>

extern NSError *revenant_device_check_unsupported(void);
