/*
 * The credentials a proxy is asked with, which arrived before the rest of proxy_config.h did: the
 * caches name it in 16.0 and the factories in 18.0, so it is a file of its own.
 */

#import "CharonNW.h"

void nw_proxy_config_set_username_and_password(nw_proxy_config_t proxy_config, const char *username, const char *password)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)proxy_config;
    if (!value)
        return;
    value->_username = username ? @(username) : nil;
    value->_password = password ? @(password) : nil;
}

