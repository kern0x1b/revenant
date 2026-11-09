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
    @"(function(names,nonce,opener){"
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
    @"var table=window[nonce+'p']||(window[nonce+'p']={});var opened=0;var base=String(Math.random()).slice(2);"
    @"function syncPost(envelope){"
    @"var target=(location.protocol==='http:'||location.protocol==='https:')?location.protocol+'//'+location.host+'/__revenant_sync/'+nonce:'revenant-wkbridge://sync/'+nonce;"
    @"var request=new XMLHttpRequest();"
    @"try{request.open('GET',target+'?'+encodeURIComponent(JSON.stringify(envelope)),false);request.send(null);}catch(e){return null;}"
    @"return request.status===200?request.responseText:null;}"
    @"function locate(url){var link=document.createElement('a');link.href=(url===undefined||url==='')?'about:blank':String(url);return link.href;}"
    @"function revive(value){var ids=[];"
    @"function walk(x){"
    @"if(x===null||typeof x!=='object'){return x;}"
    @"var t=x['$revenant'];"
    @"if(t==='u'){return undefined;}"
    @"if(t==='n'){return x.v==='NaN'?NaN:x.v==='-0'?-0:x.v==='Infinity'?Infinity:x.v==='-Infinity'?-Infinity:undefined;}"
    @"if(t==='d'){return new Date(x.v);}"
    @"if(t==='r'){return ids[x.i];}"
    @"if(t==='a'){var array=[];ids.push(array);for(var j=0;j<x.v.length;j++){var item=walk(x.v[j]);array.push(item===undefined?null:item);}return array;}"
    @"if(t==='o'){var object={};ids.push(object);for(var k=0;k<x.k.length;k++){object[x.k[k]]=walk(x.v[k]);}return object;}"
    @"return undefined;}"
    @"return walk(value);}"
    @"function windowProxy(id){"
    @"var href='about:blank';var closed=false;"
    @"var where={get href(){return href;},set href(value){href=locate(value);post({w:4,i:id,u:href,k:nonce});},toString:function(){return href;}};"
    @"var proxy={get closed(){return closed;},get location(){return where;},set location(value){where.href=value;},"
    @"close:function(){if(!closed){closed=true;post({w:2,i:id,k:nonce});}},"
    @"postMessage:function(message,origin){post({w:3,i:id,b:encode(message),o:origin===undefined?'':String(origin),k:nonce});}};"
    @"table[id]={proxy:proxy,update:function(update){if(update.href!==undefined){href=String(update.href);}if(update.closed){closed=true;}}};"
    @"return proxy;}"
    @"function openerProxy(info){"
    @"var href=locate(info.href);var closed=false;"
    @"var where={get href(){return href;},set href(value){href=locate(value);post({w:7,u:href,k:nonce});},toString:function(){return href;}};"
    @"var proxy={get closed(){return closed;},get location(){return where;},set location(value){where.href=value;},"
    @"postMessage:function(message,origin){post({w:6,b:encode(message),o:origin===undefined?'':String(origin),k:nonce});}};"
    @"table.opener={proxy:proxy,update:function(update){if(update.href!==undefined){href=String(update.href);}if(update.closed){closed=true;}}};"
    @"return proxy;}"
    @"if(opener){if(table.opener){table.opener.update({href:opener.href});window.opener=table.opener.proxy;}else{window.opener=openerProxy(opener);}}"
    @"window.open=function(url,name,features){"
    @"var id=base+'.'+(++opened);"
    @"var answer=syncPost({w:1,i:id,b:encode({u:locate(url),t:name===undefined?'':String(name),f:features===undefined?'':String(features)}),k:nonce});"
    @"if(answer!=='1'){return null;}"
    @"return windowProxy(id);};"
    @"window.close=function(){post({w:5,k:nonce});};"
    @"window[nonce+'w']=function(update){"
    @"if(update.m!==undefined){var here=location.protocol+'//'+location.host;if(!(update.t==='*'||update.t===here||(update.t==='/'&&update.o===here))){return;}"
    @"var source=null;if(update.s==='opener'){source=table.opener?table.opener.proxy:null;}else if(table[update.s]){source=table[update.s].proxy;}"
    @"var event=document.createEvent('MessageEvent');event.initMessageEvent('message',false,false,revive(JSON.parse(update.m)),update.o,'',null,null);"
    @"try{Object.defineProperty(event,'source',{value:source});}catch(e){}"
    @"window.dispatchEvent(event);return;}"
    @"var entry=update.opener?table.opener:table[update.i];if(entry){entry.update(update);}};"
    @"window[nonce+'a']=function(id,state,value){"
    @"var envelope={w:8,i:id,s:state,k:nonce};"
    @"if(state===0){try{envelope.b=encode(value);}catch(e){envelope.s=2;}}"
    @"else if(state===1){try{envelope.m=String(value&&value.message!==undefined?value.message:value);}catch(e){envelope.m='';}"
    @"envelope.l=value&&value.line!==undefined?value.line:0;envelope.c=value&&value.column!==undefined?value.column:0;}"
    @"post(envelope);};"
    @"if(!names.length){try{delete window.webkit;}catch(e){window.webkit=undefined;}return;}"
    @"var handlers={};"
    @"names.forEach(function(name){handlers[name]={postMessage:function(body){"
    @"post({n:name,b:encode(body),k:nonce});"
    @"}};});"
    @"if(!window.webkit){window.webkit={};}"
    @"window.webkit.messageHandlers=handlers;"
    @"})(%@,\"%@\",%@)";

static const NSUInteger MaximumDepth = 64;

NSString *RevenantCodecStringLiteral(NSString *string)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[string ?: @""] options:0 error:NULL];
    NSString *array = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (array.length < 2)
        return nil;
    NSString *quoted = [array substringWithRange:NSMakeRange(1, array.length - 2)];
    quoted = [quoted stringByReplacingOccurrencesOfString:@" " withString:@"\\u2028"];
    return [quoted stringByReplacingOccurrencesOfString:@" " withString:@"\\u2029"];
}

static NSString *scriptNumber(NSNumber *number)
{
    if (CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID())
        return number.boolValue ? @"true" : @"false";
    if (!CFNumberIsFloatType((__bridge CFNumberRef)number))
        return number.stringValue;
    double value = number.doubleValue;
    if (isnan(value))
        return @"NaN";
    if (isinf(value))
        return value < 0 ? @"-Infinity" : @"Infinity";
    if (value == 0 && signbit(value))
        return @"-0";
    return [NSString stringWithFormat:@"%.17g", value];
}

static NSString *scriptLiteral(id value, NSUInteger depth)
{
    if (depth > MaximumDepth)
        return nil;
    if ([value isKindOfClass:[NSString class]])
        return RevenantCodecStringLiteral(value);
    if ([value isKindOfClass:[NSNumber class]])
        return scriptNumber(value);
    if ([value isKindOfClass:[NSNull class]])
        return @"null";
    if ([value isKindOfClass:[NSDate class]])
        return [NSString stringWithFormat:@"new Date(%.17g)", [value timeIntervalSince1970] * 1000];
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in value) {
            NSString *text = scriptLiteral(item, depth + 1);
            if (!text)
                return nil;
            [items addObject:text];
        }
        return [NSString stringWithFormat:@"[%@]", [items componentsJoinedByString:@","]];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *members = [NSMutableArray array];
        for (id key in value) {
            if (![key isKindOfClass:[NSString class]])
                return nil;
            NSString *name = RevenantCodecStringLiteral(key);
            NSString *text = scriptLiteral(value[key], depth + 1);
            if (!name || !text)
                return nil;
            [members addObject:[NSString stringWithFormat:@"[%@]:%@", name, text]];
        }
        return [NSString stringWithFormat:@"{%@}", [members componentsJoinedByString:@","]];
    }
    return nil;
}

NSString *RevenantCodecScriptLiteral(id value)
{
    return scriptLiteral(value, 0);
}

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

NSString *RevenantOriginOf(NSURL *URL)
{
    NSString *scheme = URL.scheme.lowercaseString;
    NSString *host = URL.host.lowercaseString;
    if (!host.length || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]))
        return nil;
    NSNumber *port = URL.port;
    BOOL standard = !port || ([scheme isEqualToString:@"http"] && port.integerValue == 80) || ([scheme isEqualToString:@"https"] && port.integerValue == 443);
    return standard ? [NSString stringWithFormat:@"%@://%@", scheme, host] : [NSString stringWithFormat:@"%@://%@:%@", scheme, host, port];
}

BOOL RevenantTargetAllows(NSString *target, NSString *senderOrigin, NSString *recipientOrigin)
{
    if (![target isKindOfClass:[NSString class]])
        return NO;
    if ([target isEqualToString:@"*"] || [target isEqualToString:recipientOrigin])
        return YES;
    return [target isEqualToString:@"/"] && senderOrigin && [recipientOrigin isEqualToString:senderOrigin];
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
