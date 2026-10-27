#import <Foundation/Foundation.h>

#import "RevenantScriptCodec.h"


NSString *const RevenantWebKitBridgeScheme = @"revenant-wkbridge";

NSString *const RevenantEncoder =
    @"function(v){"
    @"var seen=[];"
    @"function walk(x,top,inArray){"
    @"var t=typeof x;"
    @"if(x===undefined){if(top){return {'$revenant':'u'};}return inArray?null:undefined;}"
    @"if(x===null||t==='string'||t==='boolean'){return x;}"
    @"if(t==='number'){if(!isFinite(x)){return {'$revenant':'n','v':String(x)};}if(x===0&&1/x<0){return {'$revenant':'n','v':'-0'};}return x;}"
    @"if(t==='function'){throw {unsupported:1};}"
    @"var tag=Object.prototype.toString.call(x);"
    @"if(tag==='[object Date]'){return isNaN(x.getTime())?null:{'$revenant':'d','v':x.getTime()};}"
    @"if(tag==='[object Arguments]'){throw {unsupported:1};}"
    @"var seenAt=seen.indexOf(x);"
    @"if(seenAt>=0){return {'$revenant':'r','i':seenAt};}"
    @"seen.push(x);"
    @"if(Array.isArray(x)){var items=[];for(var j=0;j<x.length;j++){items.push(walk(x[j],false,true));}return {'$revenant':'a','v':items};}"
    @"var keys=[],values=[];"
    @"for(var k in x){if(Object.prototype.hasOwnProperty.call(x,k)&&typeof x[k]!=='function'){var w=walk(x[k],false,false);if(w!==undefined){keys.push(k);values.push(w);}}}"
    @"return {'$revenant':'o','k':keys,'v':values};"
    @"}"
    @"return JSON.stringify(walk(v,true,false));}";

NSString *const RevenantShim =
    @"(function(names){"
    @"if(!names.length){try{delete window.webkit;}catch(e){window.webkit=undefined;}return;}"
    @"var encode=%@;"
    @"var top=window===window.top;"
    @"var handlers={};"
    @"names.forEach(function(name){handlers[name]={postMessage:function(body){"
    @"var text=encode(body);"
    @"var frame=document.createElement('iframe');"
    @"frame.style.display='none';"
    @"frame.src='" @"revenant-wkbridge" @"://m/'+encodeURIComponent(JSON.stringify({n:name,b:text,m:top}));"
    @"(document.documentElement||document.body).appendChild(frame);"
    @"setTimeout(function(){if(frame.parentNode){frame.parentNode.removeChild(frame);}},0);"
    @"}};});"
    @"if(!window.webkit){window.webkit={};}"
    @"window.webkit.messageHandlers=handlers;"
    @"})(%@)";

static id decode(id value, NSMutableArray *ids)
{
    if (![value isKindOfClass:[NSDictionary class]])
        return value;
    NSString *kind = value[@"$revenant"];
    if ([kind isEqualToString:@"d"])
        return [NSDate dateWithTimeIntervalSince1970:[value[@"v"] doubleValue] / 1000];
    if ([kind isEqualToString:@"n"]) {
        NSString *name = value[@"v"];
        if ([name isEqualToString:@"NaN"])
            return @(NAN);
        if ([name isEqualToString:@"-0"])
            return @(-0.0);
        return [name hasPrefix:@"-"] ? @(-INFINITY) : @(INFINITY);
    }
    if ([kind isEqualToString:@"r"]) {
        NSUInteger index = [value[@"i"] unsignedIntegerValue];
        return index < ids.count ? ids[index] : nil;
    }
    if ([kind isEqualToString:@"a"]) {
        NSMutableArray *array = [NSMutableArray array];
        [ids addObject:array];
        for (id item in value[@"v"])
            [array addObject:decode(item, ids) ?: [NSNull null]];
        return array;
    }
    if ([kind isEqualToString:@"o"]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [ids addObject:dictionary];
        NSArray *keys = value[@"k"], *values = value[@"v"];
        for (NSUInteger index = 0; index < keys.count && index < values.count; index++)
            dictionary[keys[index]] = decode(values[index], ids) ?: [NSNull null];
        return dictionary;
    }
    return nil;
}

id RevenantCodecDecoded(id value)
{
    return decode(value, [NSMutableArray array]);
}

id RevenantCodecParsed(NSString *text, BOOL *valid)
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:NULL] : nil;
    *valid = object != nil;
    return object;
}

NSDictionary *RevenantCodecBridgeMessage(NSURL *URL)
{
    if (![URL.scheme isEqualToString:RevenantWebKitBridgeScheme])
        return nil;
    NSString *prefix = [RevenantWebKitBridgeScheme stringByAppendingString:@"://m/"];
    NSString *encoded = [URL.absoluteString substringFromIndex:MIN(prefix.length, URL.absoluteString.length)];
    BOOL valid = NO;
    NSDictionary *message = RevenantCodecParsed([encoded stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], &valid);
    return valid && [message isKindOfClass:[NSDictionary class]] ? message : nil;
}

id RevenantCodecMessageBody(id encoded, BOOL *valid)
{
    if (![encoded isKindOfClass:[NSString class]]) {
        *valid = NO;
        return nil;
    }
    id object = RevenantCodecParsed(encoded, valid);
    return *valid ? RevenantCodecDecoded(object) : nil;
}
