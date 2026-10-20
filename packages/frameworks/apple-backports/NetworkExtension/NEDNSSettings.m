#import "RevenantNEDNSSettings.h"

@implementation NEDNSSettings {
    NSArray<NSString *> *_servers;
    NEDNSProtocol _dnsProtocol;
    NSArray<NSString *> *_searchDomains;
    NSString *_domainName;
    NSArray<NSString *> *_matchDomains;
    BOOL _matchDomainsNoSearch;
    BOOL _allowFailover;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dnsProtocol = (NEDNSProtocol)0;
        _matchDomainsNoSearch = YES;
    }
    return self;
}

- (instancetype)initWithServers:(NSArray<NSString *> *)servers
{
    self = [self init];
    if (self)
        _servers = [servers copy];
    return self;
}

- (NSArray<NSString *> *)servers
{
    return _servers;
}

- (NEDNSProtocol)dnsProtocol
{
    return _dnsProtocol;
}

- (void)setDnsProtocol:(NEDNSProtocol)protocol
{
    _dnsProtocol = protocol;
}

- (NSArray<NSString *> *)searchDomains
{
    return _searchDomains;
}

- (void)setSearchDomains:(NSArray<NSString *> *)searchDomains
{
    _searchDomains = [searchDomains copy];
}

- (NSString *)domainName
{
    return _domainName;
}

- (void)setDomainName:(NSString *)domainName
{
    _domainName = [domainName copy];
}

- (NSArray<NSString *> *)matchDomains
{
    return _matchDomains;
}

- (void)setMatchDomains:(NSArray<NSString *> *)matchDomains
{
    _matchDomains = [matchDomains copy];
}

- (BOOL)matchDomainsNoSearch
{
    return _matchDomainsNoSearch;
}

- (void)setMatchDomainsNoSearch:(BOOL)flag
{
    _matchDomainsNoSearch = flag;
}

- (BOOL)allowFailover
{
    return _allowFailover;
}

- (void)setAllowFailover:(BOOL)flag
{
    _allowFailover = flag;
}

- (id)copyWithZone:(NSZone *)zone
{
    NEDNSSettings *copy = [[NEDNSSettings allocWithZone:zone] initWithServers:_servers];
    copy->_dnsProtocol = _dnsProtocol;
    copy->_searchDomains = [_searchDomains copy];
    copy->_domainName = [_domainName copy];
    copy->_matchDomains = [_matchDomains copy];
    copy->_matchDomainsNoSearch = _matchDomainsNoSearch;
    copy->_allowFailover = _allowFailover;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _servers = [[coder decodeObjectOfClass:[NSArray class] forKey:@"servers"] copy];
        _dnsProtocol = (NEDNSProtocol)[coder decodeIntegerForKey:@"dnsProtocol"];
        _searchDomains = [[coder decodeObjectOfClass:[NSArray class] forKey:@"searchDomains"] copy];
        _domainName = [[coder decodeObjectOfClass:[NSString class] forKey:@"domainName"] copy];
        _matchDomains = [[coder decodeObjectOfClass:[NSArray class] forKey:@"matchDomains"] copy];
        _matchDomainsNoSearch = [coder decodeBoolForKey:@"matchDomainsNoSearch"];
        _allowFailover = [coder decodeBoolForKey:@"allowFailover"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_servers forKey:@"servers"];
    [coder encodeInteger:_dnsProtocol forKey:@"dnsProtocol"];
    [coder encodeObject:_searchDomains forKey:@"searchDomains"];
    [coder encodeObject:_domainName forKey:@"domainName"];
    [coder encodeObject:_matchDomains forKey:@"matchDomains"];
    [coder encodeBool:_matchDomainsNoSearch forKey:@"matchDomainsNoSearch"];
    [coder encodeBool:_allowFailover forKey:@"allowFailover"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
