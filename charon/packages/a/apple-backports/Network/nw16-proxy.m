#import "CharonNW.h"

void nw_proxy_config_set_username_and_password(nw_proxy_config_t proxy_config, const char *username, const char *password)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)proxy_config;
    if (!value)
        return;
    value->_username = username ? @(username) : nil;
    value->_password = password ? @(password) : nil;
}
