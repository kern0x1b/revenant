/*
 * The two calls of iOS 13 that are about a path: whether it is constrained, and the gateways it
 * goes through.
 *
 * Constrained is Low Data Mode, which the release this port builds for does not have: no path of it
 * is ever constrained, which is the answer the system gives for a device with the mode off.
 *
 * The gateways are the addresses a packet leaves by on its way out, and the release's own way of
 * naming the router of an interface is the one ioctl that needs no privilege: a point-to-point
 * interface - which is what a cellular data connection on this release is - is told its destination
 * by SIOCGIFDSTADDR. A Wi-Fi interface is not point-to-point and has no such answer, so nothing is
 * enumerated for it; the fact and the measurement that shows it are in facts/Network/NWPath.md.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

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
