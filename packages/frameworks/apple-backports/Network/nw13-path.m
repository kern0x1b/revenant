#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <ifaddrs.h>
#include <net/if.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

bool nw_path_is_constrained(nw_path_t path)
{
    (void)path;
    return false;
}

void nw_path_enumerate_gateways(nw_path_t path, nw_path_enumerate_gateways_block_t enumerate_block)
{
    if (!path || !enumerate_block)
        return;
    int probe = socket(AF_INET, SOCK_DGRAM, 0);
    if (probe < 0)
        return;
    nw_path_enumerate_interfaces(path, ^bool(nw_interface_t interface) {
        const char *name = nw_interface_get_name(interface);
        if (!name)
            return true;
        struct ifreq request;
        memset(&request, 0, sizeof request);
        strncpy(request.ifr_name, name, IFNAMSIZ - 1);
        if (ioctl(probe, SIOCGIFDSTADDR, &request) != 0)
            return true;
        struct sockaddr *gateway = (struct sockaddr *)&request.ifr_dstaddr;
        if (gateway->sa_family != AF_INET && gateway->sa_family != AF_INET6)
            return true;
        nw_endpoint_t endpoint = nw_endpoint_create_address(gateway);
        if (!endpoint)
            return true;
        bool keep_going = enumerate_block(endpoint);

        return keep_going;
    });
    close(probe);
}
