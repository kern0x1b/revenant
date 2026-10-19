/*
 * nw_path_monitor_prohibit_interface_type, the one call of iOS 14 the path monitor has: a type of
 * interface this monitor will not report a path over.
 *
 * The monitor works the interface list out of the device's own interfaces for every path it reports,
 * and a type named here is left out of that list, so a path over it is reported as one with no
 * interface - which is what a monitor that is not allowed to use that interface can honestly say
 * about it. The types are kept in the monitor the header declares, and NWPathMonitor.m reads them
 * where it reads the reachability.
 */

#import "CharonNWPathMonitor.h"

void nw_path_monitor_prohibit_interface_type(nw_path_monitor_t monitor, nw_interface_type_t interface_type)
{
    CharonNWPathMonitor *value = (CharonNWPathMonitor *)monitor;
    if (!value)
        return;
    if (!value->_prohibitedTypes)
        value->_prohibitedTypes = [NSMutableArray array];
    [value->_prohibitedTypes addObject:@(interface_type)];
}
