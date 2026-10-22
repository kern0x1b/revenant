#import "RevenantHeaderBytes.h"

static NSString *revenant_reason(NSInteger status)
{
    switch (status) {
    case 100: return @"Continue";
    case 101: return @"Switching Protocols";
    case 200: return @"OK";
    case 201: return @"Created";
    case 202: return @"Accepted";
    case 203: return @"Non-Authoritative Information";
    case 204: return @"No Content";
    case 205: return @"Reset Content";
    case 206: return @"Partial Content";
    case 300: return @"Multiple Choices";
    case 301: return @"Moved Permanently";
    case 302: return @"Found";
    case 303: return @"See Other";
    case 304: return @"Not Modified";
    case 305: return @"Use Proxy";
    case 307: return @"Temporary Redirect";
    case 308: return @"Permanent Redirect";
    case 400: return @"Bad Request";
    case 401: return @"Unauthorized";
    case 402: return @"Payment Required";
    case 403: return @"Forbidden";
    case 404: return @"Not Found";
    case 405: return @"Method Not Allowed";
    case 406: return @"Not Acceptable";
    case 407: return @"Proxy Authentication Required";
    case 408: return @"Request Timeout";
    case 409: return @"Conflict";
    case 410: return @"Gone";
    case 411: return @"Length Required";
    case 412: return @"Precondition Failed";
    case 413: return @"Content Too Large";
    case 414: return @"URI Too Long";
    case 415: return @"Unsupported Media Type";
    case 416: return @"Range Not Satisfiable";
    case 417: return @"Expectation Failed";
    case 421: return @"Misdirected Request";
    case 422: return @"Unprocessable Content";
    case 426: return @"Upgrade Required";
    case 429: return @"Too Many Requests";
    case 500: return @"Internal Server Error";
    case 501: return @"Not Implemented";
    case 502: return @"Bad Gateway";
    case 503: return @"Service Unavailable";
    case 504: return @"Gateway Timeout";
    case 505: return @"HTTP Version Not Supported";
    default: return @"";
    }
}

static int64_t revenant_fields_bytes(NSDictionary *fields)
{
    int64_t total = 0;
    for (NSString *name in fields)
        total += (int64_t)[[NSString stringWithFormat:@"%@: %@\r\n", name, fields[name]] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    return total;
}

int64_t revenant_request_header_bytes(NSURLRequest *request)
{
    NSURL *url = request.URL;
    NSString *target = url.path.length ? url.path : @"/";
    if (url.query)
        target = [target stringByAppendingFormat:@"?%@", url.query];
    NSMutableDictionary *fields = [(request.allHTTPHeaderFields ?: @{}) mutableCopy];
    BOOL hasHost = NO;
    for (NSString *name in fields)
        hasHost = hasHost || [name caseInsensitiveCompare:@"Host"] == NSOrderedSame;
    if (!hasHost && url.host)
        fields[@"Host"] = url.port ? [NSString stringWithFormat:@"%@:%@", url.host, url.port] : url.host;
    NSString *line = [NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\n", request.HTTPMethod ?: @"GET", target];
    return (int64_t)[line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + revenant_fields_bytes(fields) + 2;
}

int64_t revenant_response_header_bytes(NSHTTPURLResponse *response)
{
    NSString *line = [NSString stringWithFormat:@"HTTP/1.1 %ld %@\r\n", (long)response.statusCode, revenant_reason(response.statusCode)];
    return (int64_t)[line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + revenant_fields_bytes(response.allHeaderFields) + 2;
}
