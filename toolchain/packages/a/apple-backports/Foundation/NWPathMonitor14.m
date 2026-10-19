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
