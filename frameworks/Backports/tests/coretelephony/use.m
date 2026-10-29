#import <CoreTelephony/CTTelephonyNetworkInfo.h>

NSDictionary *coretelephony_service_probe(CTTelephonyNetworkInfo *info)
{
    return info.serviceCurrentRadioAccessTechnology;
}
