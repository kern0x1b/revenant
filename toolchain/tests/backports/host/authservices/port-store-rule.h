#ifndef PORT_STORE_RULE_H
#define PORT_STORE_RULE_H

#include <string.h>
#include <objc/runtime.h>

static inline const char *port_store_receiver_class(id receiver)
{
    return object_getClass(receiver) ? class_getName(object_getClass(receiver)) : "?";
}

static inline int port_store_receiver_is_the_ports(id receiver, const char *prefix)
{
    const char *name = port_store_receiver_class(receiver);
    return name && prefix && strncmp(name, prefix, strlen(prefix)) == 0;
}

#endif
