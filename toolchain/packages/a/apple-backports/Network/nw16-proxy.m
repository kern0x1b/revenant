#import "RevenantNW.h"

void nw_proxy_config_set_username_and_password(nw_proxy_config_t proxy_config, const char *username, const char *password)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)proxy_config;
    if (!value)
        return;
    value->_username = username ? @(username) : nil;
    value->_password = password ? @(password) : nil;
}
