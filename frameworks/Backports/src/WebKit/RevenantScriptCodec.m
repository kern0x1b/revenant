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
    @"(function(names,nonce){"
    @"var all=document.getElementsByTagName('script');"
    @"var mine=all[all.length-1];"
    @"if(mine&&mine.firstChild&&String(mine.firstChild.nodeValue).indexOf(nonce)>=0){mine.parentNode.removeChild(mine);}"
    @"window[nonce]=true;"
    @"var encode=%@;"
    @"function post(envelope){"
    @"var frame=document.createElement('iframe');"
    @"frame.style.display='none';"
    @"frame.src='" @"revenant-wkbridge" @"://m/'+encodeURIComponent(JSON.stringify(envelope));"
    @"(document.documentElement||document.body).appendChild(frame);"
    @"setTimeout(function(){if(frame.parentNode){frame.parentNode.removeChild(frame);}},0);"
    @"}"
    @"window.open=function(url,name,features){"
    @"var link=document.createElement('a');"
    @"link.href=(url===undefined||url==='')?'about:blank':String(url);"
    @"post({w:1,b:encode({u:link.href,t:name===undefined?'':String(name),f:features===undefined?'':String(features)}),k:nonce});"
    @"return null;};"
    @"if(!names.length){try{delete window.webkit;}catch(e){window.webkit=undefined;}return;}"
    @"var handlers={};"
    @"names.forEach(function(name){handlers[name]={postMessage:function(body){"
    @"post({n:name,b:encode(body),k:nonce});"
    @"}};});"
    @"if(!window.webkit){window.webkit={};}"
    @"window.webkit.messageHandlers=handlers;"
    @"})(%@,\"%@\")";

static const NSUInteger MaximumDepth = 64;

static id decode(id value, NSMutableArray *ids, NSUInteger depth)
{
    if (![value isKindOfClass:[NSDictionary class]])
        return value;
    if (depth > MaximumDepth)
        return nil;
    NSString *kind = value[@"$revenant"];
    if (![kind isKindOfClass:[NSString class]])
        return nil;
    if ([kind isEqualToString:@"d"]) {
        NSNumber *time = value[@"v"];
        return [time isKindOfClass:[NSNumber class]] ? [NSDate dateWithTimeIntervalSince1970:time.doubleValue / 1000] : nil;
    }
    if ([kind isEqualToString:@"n"]) {
        NSString *name = value[@"v"];
        if (![name isKindOfClass:[NSString class]])
            return nil;
        if ([name isEqualToString:@"NaN"])
            return @(NAN);
        if ([name isEqualToString:@"-0"])
            return @(-0.0);
        return [name hasPrefix:@"-"] ? @(-INFINITY) : @(INFINITY);
    }
    if ([kind isEqualToString:@"r"]) {
        NSNumber *index = value[@"i"];
        if (![index isKindOfClass:[NSNumber class]])
            return nil;
        NSUInteger position = index.unsignedIntegerValue;
        return position < ids.count ? ids[position] : nil;
    }
    if ([kind isEqualToString:@"a"]) {
        NSArray *items = value[@"v"];
        if (![items isKindOfClass:[NSArray class]])
            return nil;
        NSMutableArray *array = [NSMutableArray array];
        [ids addObject:array];
        for (id item in items)
            [array addObject:decode(item, ids, depth + 1) ?: [NSNull null]];
        return array;
    }
    if ([kind isEqualToString:@"o"]) {
        NSArray *keys = value[@"k"], *values = value[@"v"];
        if (![keys isKindOfClass:[NSArray class]] || ![values isKindOfClass:[NSArray class]])
            return nil;
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [ids addObject:dictionary];
        for (NSUInteger index = 0; index < keys.count && index < values.count; index++) {
            if (![keys[index] isKindOfClass:[NSString class]])
                continue;
            dictionary[keys[index]] = decode(values[index], ids, depth + 1) ?: [NSNull null];
        }
        return dictionary;
    }
    return nil;
}

id RevenantCodecDecoded(id value)
{
    return decode(value, [NSMutableArray array], 0);
}

id RevenantCodecParsed(NSString *text, BOOL *valid)
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:NULL] : nil;
    *valid = object != nil;
    return object;
}

NSDictionary *RevenantCodecBridgeMessage(NSURL *URL, NSString *nonce)
{
    if (![URL.scheme isEqualToString:RevenantWebKitBridgeScheme])
        return nil;
    NSString *prefix = [RevenantWebKitBridgeScheme stringByAppendingString:@"://m/"];
    NSString *encoded = [URL.absoluteString substringFromIndex:MIN(prefix.length, URL.absoluteString.length)];
    BOOL valid = NO;
    NSDictionary *message = RevenantCodecParsed([encoded stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], &valid);
    if (!valid || ![message isKindOfClass:[NSDictionary class]])
        return nil;
    NSString *presented = message[@"k"];
    if (![presented isKindOfClass:[NSString class]] || !nonce.length || ![presented isEqualToString:nonce])
        return nil;
    return message;
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
