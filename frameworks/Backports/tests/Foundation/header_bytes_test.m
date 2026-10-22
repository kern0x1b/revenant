#import "check.h"
#import "RevenantHeaderBytes.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com:8080/a/b?x=1"]];
    request.HTTPMethod = @"POST";
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    NSString *wire = @"POST /a/b?x=1 HTTP/1.1\r\nHost: example.com:8080\r\nContent-Type: text/plain\r\n\r\n";
    int64_t expected = (int64_t)wire.length + (revenant_negative ? 1 : 0);
    revenant_check(revenant_request_header_bytes(request) == expected, "a request counts its line, fields and blank line", [NSString stringWithFormat:@"%lld is not %lld", revenant_request_header_bytes(request), expected]);
    NSMutableURLRequest *given = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com/"]];
    [given setValue:@"other.example" forHTTPHeaderField:@"Host"];
    NSString *givenWire = @"GET / HTTP/1.1\r\nHost: other.example\r\n\r\n";
    revenant_check(revenant_request_header_bytes(given) == (int64_t)givenWire.length, "a Host field of the request is not added twice", [NSString stringWithFormat:@"%lld", revenant_request_header_bytes(given)]);
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com/"] statusCode:404 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Length": @"9"}];
    NSString *responseWire = @"HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\n";
    revenant_check(revenant_response_header_bytes(response) == (int64_t)responseWire.length, "a response counts its status line, fields and blank line", [NSString stringWithFormat:@"%lld", revenant_response_header_bytes(response)]);
    return revenant_finish();
}
