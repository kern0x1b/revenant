#import "CharonNetworkExtensionSettings.h"

/* The proxy settings object and the proxy server it holds. Both are state: the system reads them
   when a configuration is applied, so the answer to every getter is the value a caller set, and the
   header's own defaults are what a fresh object answers.
   The names are Apple's, capitalised where Apple capitalises them (HTTPEnabled, HTTPSEnabled,
   HTTPSServer), because a differently-spelled selector is a different API and would not link. */
@implementation NEProxyServer {
    NSString *_address;
    NSInteger _port;
    BOOL _authenticationRequired;
    NSString *_username;
    NSString *_password;
}

- (instancetype)initWithAddress:(NSString *)address port:(NSInteger)port
{
    self = [super init];
    if (self) {
        _address = [address copy];
        _port = port;
    }
    return self;
}

- (NSString *)address { return _address; }
- (NSInteger)port { return _port; }

- (BOOL)authenticationRequired { return _authenticationRequired; }
- (void)setAuthenticationRequired:(BOOL)flag { _authenticationRequired = flag; }

- (NSString *)username { return _username; }
- (void)setUsername:(NSString *)username { _username = [username copy]; }

- (NSString *)password { return _password; }
- (void)setPassword:(NSString *)password { _password = [password copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NEProxyServer *copy = [[NEProxyServer allocWithZone:zone] initWithAddress:_address port:_port];
    copy->_authenticationRequired = _authenticationRequired;
    copy->_username = [_username copy];
    copy->_password = [_password copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _address = [[coder decodeObjectOfClass:[NSString class] forKey:@"address"] copy];
        _port = [coder decodeIntegerForKey:@"port"];
        _authenticationRequired = [coder decodeBoolForKey:@"authenticationRequired"];
        _username = [[coder decodeObjectOfClass:[NSString class] forKey:@"username"] copy];
        _password = [[coder decodeObjectOfClass:[NSString class] forKey:@"password"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_address forKey:@"address"];
    [coder encodeInteger:_port forKey:@"port"];
    [coder encodeBool:_authenticationRequired forKey:@"authenticationRequired"];
    [coder encodeObject:_username forKey:@"username"];
    [coder encodeObject:_password forKey:@"password"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end

@implementation NEProxySettings {
    BOOL _autoProxyConfigurationEnabled;
    NSURL *_proxyAutoConfigurationURL;
    NSString *_proxyAutoConfigurationJavaScript;
    BOOL _httpEnabled;
    NEProxyServer *_httpServer;
    BOOL _httpsEnabled;
    NEProxyServer *_httpsServer;
    BOOL _excludeSimpleHostnames;
    NSArray<NSString *> *_exceptionList;
    NSArray<NSString *> *_matchDomains;
}

- (BOOL)autoProxyConfigurationEnabled { return _autoProxyConfigurationEnabled; }
- (void)setAutoProxyConfigurationEnabled:(BOOL)flag { _autoProxyConfigurationEnabled = flag; }

- (NSURL *)proxyAutoConfigurationURL { return _proxyAutoConfigurationURL; }
- (void)setProxyAutoConfigurationURL:(NSURL *)URL { _proxyAutoConfigurationURL = [URL copy]; }

- (NSString *)proxyAutoConfigurationJavaScript { return _proxyAutoConfigurationJavaScript; }
- (void)setProxyAutoConfigurationJavaScript:(NSString *)script { _proxyAutoConfigurationJavaScript = [script copy]; }

- (BOOL)HTTPEnabled { return _httpEnabled; }
- (void)setHTTPEnabled:(BOOL)flag { _httpEnabled = flag; }

- (NEProxyServer *)HTTPServer { return _httpServer; }
- (void)setHTTPServer:(NEProxyServer *)server { _httpServer = [server copy]; }

- (BOOL)HTTPSEnabled { return _httpsEnabled; }
- (void)setHTTPSEnabled:(BOOL)flag { _httpsEnabled = flag; }

- (NEProxyServer *)HTTPSServer { return _httpsServer; }
- (void)setHTTPSServer:(NEProxyServer *)server { _httpsServer = [server copy]; }

- (BOOL)excludeSimpleHostnames { return _excludeSimpleHostnames; }
- (void)setExcludeSimpleHostnames:(BOOL)flag { _excludeSimpleHostnames = flag; }

- (NSArray<NSString *> *)exceptionList { return _exceptionList; }
- (void)setExceptionList:(NSArray<NSString *> *)list { _exceptionList = [list copy]; }

- (NSArray<NSString *> *)matchDomains { return _matchDomains; }
- (void)setMatchDomains:(NSArray<NSString *> *)domains { _matchDomains = [domains copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NEProxySettings *copy = [[NEProxySettings allocWithZone:zone] init];
    copy->_autoProxyConfigurationEnabled = _autoProxyConfigurationEnabled;
    copy->_proxyAutoConfigurationURL = [_proxyAutoConfigurationURL copy];
    copy->_proxyAutoConfigurationJavaScript = [_proxyAutoConfigurationJavaScript copy];
    copy->_httpEnabled = _httpEnabled;
    copy->_httpServer = [_httpServer copy];
    copy->_httpsEnabled = _httpsEnabled;
    copy->_httpsServer = [_httpsServer copy];
    copy->_excludeSimpleHostnames = _excludeSimpleHostnames;
    copy->_exceptionList = [_exceptionList copy];
    copy->_matchDomains = [_matchDomains copy];
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _autoProxyConfigurationEnabled = [coder decodeBoolForKey:@"autoProxyConfigurationEnabled"];
        _proxyAutoConfigurationURL = [[coder decodeObjectOfClass:[NSURL class] forKey:@"proxyAutoConfigurationURL"] copy];
        _proxyAutoConfigurationJavaScript = [[coder decodeObjectOfClass:[NSString class] forKey:@"proxyAutoConfigurationJavaScript"] copy];
        _httpEnabled = [coder decodeBoolForKey:@"HTTPEnabled"];
        _httpServer = [[coder decodeObjectOfClass:[NEProxyServer class] forKey:@"HTTPServer"] copy];
        _httpsEnabled = [coder decodeBoolForKey:@"HTTPSEnabled"];
        _httpsServer = [[coder decodeObjectOfClass:[NEProxyServer class] forKey:@"HTTPSServer"] copy];
        _excludeSimpleHostnames = [coder decodeBoolForKey:@"excludeSimpleHostnames"];
        _exceptionList = [[coder decodeObjectOfClass:[NSArray class] forKey:@"exceptionList"] copy];
        _matchDomains = [[coder decodeObjectOfClass:[NSArray class] forKey:@"matchDomains"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_autoProxyConfigurationEnabled forKey:@"autoProxyConfigurationEnabled"];
    [coder encodeObject:_proxyAutoConfigurationURL forKey:@"proxyAutoConfigurationURL"];
    [coder encodeObject:_proxyAutoConfigurationJavaScript forKey:@"proxyAutoConfigurationJavaScript"];
    [coder encodeBool:_httpEnabled forKey:@"HTTPEnabled"];
    [coder encodeObject:_httpServer forKey:@"HTTPServer"];
    [coder encodeBool:_httpsEnabled forKey:@"HTTPSEnabled"];
    [coder encodeObject:_httpsServer forKey:@"HTTPSServer"];
    [coder encodeBool:_excludeSimpleHostnames forKey:@"excludeSimpleHostnames"];
    [coder encodeObject:_exceptionList forKey:@"exceptionList"];
    [coder encodeObject:_matchDomains forKey:@"matchDomains"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end
