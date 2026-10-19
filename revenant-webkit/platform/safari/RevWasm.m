#import "RevWasm.h"
#include "wasm3.h"
#include "m3_env.h"

@interface NSObject (RevWasmWebKit)
- (id)windowScriptObject;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (id)callWebScriptMethod:(NSString *)name withArguments:(NSArray *)args;
@end

@class RevWasmHost;

typedef struct {
    RevWasmHost *host;
    int instanceId;
    int ordinal;         // position among this module's function imports
    char argTypes[16];   // 'i' 'I' 'f' 'F'
    int argc;
    char retType;        // 'i' 'I' 'f' 'F' 'v'
} RevWasmImport;

@interface RevWasmInstance : NSObject {
@public
    IM3Runtime rt;
    IM3Module mod;
    NSData *bytes;
    RevWasmImport *imports;
    int numImports;
}
@end
@implementation RevWasmInstance
- (void)dealloc {
    if (rt) m3_FreeRuntime(rt);
    [bytes release];
    if (imports) free(imports);
    [super dealloc];
}
@end

static uint32_t readLEB(const uint8_t **p, const uint8_t *end) {
    uint32_t r = 0; int s = 0; uint8_t b;
    do { if (*p >= end) return r; b = *(*p)++; r |= (uint32_t)(b & 0x7f) << s; s += 7; } while (b & 0x80);
    return r;
}
static char wasmTypeChar(uint8_t t) {
    switch (t) { case 0x7f: return 'i'; case 0x7e: return 'I'; case 0x7d: return 'f'; case 0x7c: return 'F'; }
    return 'i';
}

@class RevWasmHost;

@interface RevWasmHost : NSObject {
@public
    IM3Environment _env;
    NSMutableDictionary *_instances;
    int _nextId;
    WebView *_webView;
}
- (NSString *)op:(NSString *)json;
@end

static const void *revWasmTrampoline(IM3Runtime rt, IM3ImportContext ctx, uint64_t *sp, void *mem) {
    RevWasmImport *imp = (RevWasmImport *)ctx->userdata;
    int argBase = (imp->retType != 'v') ? 1 : 0;
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:imp->argc];
    for (int i = 0; i < imp->argc; i++) {
        uint64_t slot = sp[argBase + i];
        switch (imp->argTypes[i]) {
            case 'I': [args addObject:[NSNumber numberWithLongLong:(long long)slot]]; break;
            case 'f': [args addObject:[NSNumber numberWithFloat:*(float *)&slot]]; break;
            case 'F': [args addObject:[NSNumber numberWithDouble:*(double *)&slot]]; break;
            default:  [args addObject:[NSNumber numberWithInt:(int)(uint32_t)slot]]; break;
        }
    }
    NSData *aj = [NSJSONSerialization dataWithJSONObject:args options:0 error:NULL];
    NSString *argsJson = [[[NSString alloc] initWithData:aj encoding:NSUTF8StringEncoding] autorelease];
    id win = [(id)imp->host->_webView windowScriptObject];
    id res = [win callWebScriptMethod:@"__revwasm_dispatch"
        withArguments:[NSArray arrayWithObjects:
            [NSNumber numberWithInt:imp->instanceId], [NSNumber numberWithInt:imp->ordinal], argsJson, nil]];
    double rv = [res respondsToSelector:@selector(doubleValue)] ? [res doubleValue] : 0;
    if (imp->retType != 'v') {
        switch (imp->retType) {
            case 'I': *(uint64_t *)&sp[0] = (uint64_t)(long long)rv; break;
            case 'f': *(float *)&sp[0] = (float)rv; break;
            case 'F': *(double *)&sp[0] = rv; break;
            default:  *(uint64_t *)&sp[0] = (uint32_t)(int64_t)rv; break;
        }
    }
    return NULL;
}

static NSData *b64decode(NSString *s) {
    if ([s respondsToSelector:@selector(initWithBase64EncodedString:options:)])
        return [[[NSData alloc] initWithBase64EncodedString:s options:0] autorelease];
    return [[[NSData alloc] initWithBase64Encoding:s] autorelease];
}

@implementation RevWasmHost

- (id)init {
    if ((self = [super init])) {
        _env = m3_NewEnvironment();
        _instances = [[NSMutableDictionary alloc] init];
        _nextId = 1;
    }
    return self;
}

- (void)dealloc {
    [_instances release];
    if (_env) m3_FreeEnvironment(_env);
    [super dealloc];
}

static NSString *jsonOut(NSDictionary *d) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

- (NSString *)instantiate:(NSString *)b64 {
    NSData *bytes = b64decode(b64);
    if (![bytes length]) return jsonOut(@{@"ok": @NO, @"err": @"empty module"});

    IM3Runtime rt = m3_NewRuntime(_env, 512 * 1024, NULL);
    if (!rt) return jsonOut(@{@"ok": @NO, @"err": @"no runtime"});
    IM3Module mod;
    M3Result r = m3_ParseModule(_env, &mod, [bytes bytes], (uint32_t)[bytes length]);
    if (r) { m3_FreeRuntime(rt); return jsonOut(@{@"ok": @NO, @"err": [NSString stringWithUTF8String:r]}); }
    r = m3_LoadModule(rt, mod);
    if (r) { m3_FreeRuntime(rt); return jsonOut(@{@"ok": @NO, @"err": [NSString stringWithUTF8String:r]}); }

    RevWasmInstance *inst = [[RevWasmInstance alloc] init];
    inst->rt = rt;
    inst->mod = mod;
    inst->bytes = [bytes retain];
    int iidInt = _nextId++;
    NSString *iid = [NSString stringWithFormat:@"%d", iidInt];

    NSMutableArray *importList = [NSMutableArray array];
    const uint8_t *base = [bytes bytes], *p = base, *end = base + [bytes length];
    if ([bytes length] > 8) {
        p += 8;
        typedef struct { char ret; int argc; char args[16]; } TSig;
        TSig *types = NULL; uint32_t numTypes = 0;
        RevWasmImport *imps = NULL; int numImps = 0;
        while (p < end) {
            uint8_t sid = *p++;
            uint32_t slen = readLEB(&p, end);
            const uint8_t *sEnd = p + slen;
            if (sEnd > end) break;
            if (sid == 1) {
                numTypes = readLEB(&p, end);
                types = calloc(numTypes ? numTypes : 1, sizeof(TSig));
                for (uint32_t t = 0; t < numTypes; t++) {
                    if (p < end && *p == 0x60) p++;
                    uint32_t np = readLEB(&p, end);
                    types[t].argc = (int)(np < 16 ? np : 16);
                    for (uint32_t a = 0; a < np; a++) { char c = wasmTypeChar(*p++); if (a < 16) types[t].args[a] = c; }
                    uint32_t nr = readLEB(&p, end);
                    types[t].ret = nr ? wasmTypeChar(*p) : 'v';
                    for (uint32_t rr = 0; rr < nr; rr++) p++;
                }
            } else if (sid == 2) {
                uint32_t nImp = readLEB(&p, end);
                imps = calloc(nImp ? nImp : 1, sizeof(RevWasmImport));
                for (uint32_t im = 0; im < nImp; im++) {
                    uint32_t ml = readLEB(&p, end); const char *mn = (const char *)p; p += ml;
                    uint32_t fl = readLEB(&p, end); const char *fn = (const char *)p; p += fl;
                    uint8_t kind = *p++;
                    if (kind == 0x00) {
                        uint32_t ti = readLEB(&p, end);
                        RevWasmImport *ip = &imps[numImps];
                        ip->host = self; ip->instanceId = iidInt; ip->ordinal = numImps;
                        if (types && ti < numTypes) {
                            ip->argc = types[ti].argc; ip->retType = types[ti].ret;
                            memcpy(ip->argTypes, types[ti].args, 16);
                        }
                        NSString *mName = [[[NSString alloc] initWithBytes:mn length:ml encoding:NSUTF8StringEncoding] autorelease];
                        NSString *fName = [[[NSString alloc] initWithBytes:fn length:fl encoding:NSUTF8StringEncoding] autorelease];
                        [importList addObject:@{@"m": mName ?: @"", @"f": fName ?: @""}];
                        numImps++;
                    } else if (kind == 0x01) { readLEB(&p, end); uint8_t fl2=*p++; readLEB(&p,end); if(fl2)readLEB(&p,end); }
                    else if (kind == 0x02) { uint8_t fl2=*p++; readLEB(&p,end); if(fl2)readLEB(&p,end); }
                    else if (kind == 0x03) { p++; p++; }
                }
            }
            p = sEnd;
        }
        if (numImps > 0) {
            inst->imports = imps; inst->numImports = numImps;
            for (int i = 0; i < numImps; i++) {
                RevWasmImport *ip = &imps[i];
                char sig[32]; int si = 0;
                sig[si++] = ip->retType; sig[si++] = '(';
                for (int a = 0; a < ip->argc && si < 29; a++) sig[si++] = ip->argTypes[a];
                sig[si++] = ')'; sig[si] = 0;
                NSDictionary *d = [importList objectAtIndex:i];
                m3_LinkRawFunctionEx(mod, [[d objectForKey:@"m"] UTF8String],
                    [[d objectForKey:@"f"] UTF8String], sig, revWasmTrampoline, ip);
            }
        } else if (imps) { free(imps); }
        if (types) free(types);
    }

    [_instances setObject:inst forKey:iid];
    [inst release];
    return jsonOut(@{@"ok": @YES, @"instance": iid, @"imports": importList});
}

- (NSString *)validate:(NSString *)b64 {
    NSData *bytes = b64decode(b64);
    IM3Runtime rt = m3_NewRuntime(_env, 64 * 1024, NULL);
    IM3Module mod;
    M3Result r = m3_ParseModule(_env, &mod, [bytes bytes], (uint32_t)[bytes length]);
    BOOL ok = (r == NULL);
    if (r == NULL) m3_FreeModule(mod);
    m3_FreeRuntime(rt);
    return jsonOut(@{@"ok": [NSNumber numberWithBool:ok]});
}

- (NSString *)call:(NSDictionary *)req {
    RevWasmInstance *inst = [_instances objectForKey:[req objectForKey:@"instance"]];
    if (!inst) return jsonOut(@{@"ok": @NO, @"err": @"bad instance"});
    IM3Runtime rt = inst->rt;
    NSString *fn = [req objectForKey:@"fn"];
    IM3Function f;
    M3Result r = m3_FindFunction(&f, rt, [fn UTF8String]);
    if (r) return jsonOut(@{@"ok": @NO, @"err": [NSString stringWithUTF8String:r]});

    NSArray *args = [req objectForKey:@"args"] ?: @[];
    uint32_t argc = m3_GetArgCount(f);
    uint64_t slots[16]; const void *ptrs[16];
    if (argc > 16) return jsonOut(@{@"ok": @NO, @"err": @"too many args"});
    for (uint32_t i = 0; i < argc; i++) {
        double a = (i < [args count]) ? [[args objectAtIndex:i] doubleValue] : 0;
        switch (m3_GetArgType(f, i)) {
            case c_m3Type_i32: *(uint32_t *)&slots[i] = (uint32_t)(int64_t)a; break;
            case c_m3Type_i64: *(uint64_t *)&slots[i] = (uint64_t)(int64_t)a; break;
            case c_m3Type_f32: *(float *)&slots[i] = (float)a; break;
            case c_m3Type_f64: *(double *)&slots[i] = a; break;
            default: *(uint64_t *)&slots[i] = (uint64_t)(int64_t)a; break;
        }
        ptrs[i] = &slots[i];
    }
    r = m3_Call(f, argc, ptrs);
    if (r) return jsonOut(@{@"ok": @NO, @"err": [NSString stringWithUTF8String:r]});

    if (m3_GetRetCount(f) == 0) return jsonOut(@{@"ok": @YES, @"result": [NSNull null]});
    uint64_t ret = 0; const void *rp[1] = { &ret };
    m3_GetResults(f, 1, rp);
    NSNumber *out;
    switch (m3_GetRetType(f, 0)) {
        case c_m3Type_i32: out = [NSNumber numberWithInt:(int)*(uint32_t *)&ret]; break;
        case c_m3Type_i64: out = [NSNumber numberWithLongLong:(long long)ret]; break;
        case c_m3Type_f32: out = [NSNumber numberWithFloat:*(float *)&ret]; break;
        case c_m3Type_f64: out = [NSNumber numberWithDouble:*(double *)&ret]; break;
        default: out = [NSNumber numberWithLongLong:(long long)ret]; break;
    }
    return jsonOut(@{@"ok": @YES, @"result": out});
}

- (NSString *)meminfo:(NSDictionary *)req {
    RevWasmInstance *inst = [_instances objectForKey:[req objectForKey:@"instance"]];
    if (!inst || !inst->mod) return jsonOut(@{@"ok": @NO, @"err": @"bad instance"});
    size_t size = 0;
    uint8_t *mem = m3_GetMemory(inst->mod, &size, 0);
    return jsonOut(@{@"ok": @YES, @"size": [NSNumber numberWithUnsignedLongLong:mem ? size : 0]});
}

- (NSString *)memread:(NSDictionary *)req {
    RevWasmInstance *inst = [_instances objectForKey:[req objectForKey:@"instance"]];
    if (!inst || !inst->mod) return jsonOut(@{@"ok": @NO, @"err": @"bad instance"});
    size_t size = 0;
    uint8_t *mem = m3_GetMemory(inst->mod, &size, 0);
    if (!mem) return jsonOut(@{@"ok": @NO, @"err": @"no memory"});
    size_t off = [[req objectForKey:@"off"] unsignedLongLongValue];
    size_t len = [[req objectForKey:@"len"] unsignedLongLongValue];
    if (off > size) off = size;
    if (off + len > size) len = size - off;
    NSData *slice = [NSData dataWithBytes:mem + off length:len];
    NSString *b64 = [slice respondsToSelector:@selector(base64EncodedStringWithOptions:)]
        ? [slice base64EncodedStringWithOptions:0] : [slice base64Encoding];
    return jsonOut(@{@"ok": @YES, @"data": b64});
}

- (NSString *)memwrite:(NSDictionary *)req {
    RevWasmInstance *inst = [_instances objectForKey:[req objectForKey:@"instance"]];
    if (!inst || !inst->mod) return jsonOut(@{@"ok": @NO, @"err": @"bad instance"});
    size_t size = 0;
    uint8_t *mem = m3_GetMemory(inst->mod, &size, 0);
    if (!mem) return jsonOut(@{@"ok": @NO, @"err": @"no memory"});
    size_t off = [[req objectForKey:@"off"] unsignedLongLongValue];
    NSData *bytes = b64decode([req objectForKey:@"data"]);
    size_t len = [bytes length];
    if (off + len > size) return jsonOut(@{@"ok": @NO, @"err": @"out of bounds"});
    memcpy(mem + off, [bytes bytes], len);
    return jsonOut(@{@"ok": @YES});
}

- (NSString *)op:(NSString *)json {
    @try {
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *req = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSString *cmd = [req objectForKey:@"cmd"];
        if ([cmd isEqualToString:@"instantiate"]) return [self instantiate:[req objectForKey:@"bytes"]];
        if ([cmd isEqualToString:@"validate"])    return [self validate:[req objectForKey:@"bytes"]];
        if ([cmd isEqualToString:@"call"])        return [self call:req];
        if ([cmd isEqualToString:@"meminfo"])     return [self meminfo:req];
        if ([cmd isEqualToString:@"memread"])     return [self memread:req];
        if ([cmd isEqualToString:@"memwrite"])    return [self memwrite:req];
        return jsonOut(@{@"ok": @NO, @"err": @"unknown cmd"});
    } @catch (NSException *e) {
        return jsonOut(@{@"ok": @NO, @"err": [e reason] ?: @"exception"});
    }
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel { return sel != @selector(op:); }
+ (NSString *)webScriptNameForSelector:(SEL)sel { return sel == @selector(op:) ? @"op" : nil; }
+ (BOOL)isKeyExcludedFromWebScript:(const char *)name { return YES; }

@end

static NSString *const kRevWasmBootstrap =
@"(function(){ if (window.WebAssembly) return; var H=window.__revwasm; if(!H) return;"
@"function b64(buf){var u=buf instanceof Uint8Array?buf:new Uint8Array(buf.buffer||buf);"
@"var s='';for(var i=0;i<u.length;i++)s+=String.fromCharCode(u[i]);return btoa(s);}"
@"function call(o){return JSON.parse(H.op(JSON.stringify(o)));}"
@"function makeInstance(id){"
@"var mem=null;var mi=call({cmd:'meminfo',instance:id});"
@"function fromWasm(){if(!mem)return;var r=call({cmd:'memread',instance:id,off:0,len:mem.buffer.byteLength});"
@"if(r.ok){var b=atob(r.data),u=new Uint8Array(mem.buffer);for(var i=0;i<b.length;i++)u[i]=b.charCodeAt(i);}}"
@"function toWasm(){if(!mem)return;var u=new Uint8Array(mem.buffer),s='';for(var i=0;i<u.length;i++)s+=String.fromCharCode(u[i]);"
@"call({cmd:'memwrite',instance:id,off:0,data:btoa(s)});}"
@"if(mi.ok&&mi.size>0){mem={buffer:new ArrayBuffer(mi.size)};fromWasm();}"
@"var ex=new Proxy({},{get:function(t,name){"
@"if(name==='memory')return mem;"
@"if(typeof name!=='string')return undefined;"
@"return function(){var args=Array.prototype.slice.call(arguments);toWasm();"
@"var r=call({cmd:'call',instance:id,fn:name,args:args});fromWasm();"
@"if(!r.ok)throw new Error('wasm call '+name+': '+r.err);return r.result;};}});"
@"return {exports:ex};}"
@"window.__revwasm_imports={};"
@"window.__revwasm_dispatch=function(instId,ord,argsJson){"
@"var m=window.__revwasm_imports[instId];var fn=m&&m[ord];if(typeof fn!=='function')return 0;"
@"var args;try{args=JSON.parse(argsJson);}catch(e){args=[];}"
@"var r=fn.apply(null,args);return (typeof r==='number')?r:(r?1:0);};"
@"function registerImports(instId,list,importObject){var arr=[];"
@"for(var i=0;i<list.length;i++){var im=list[i];var mo=importObject&&importObject[im.m];"
@"var fn=mo&&mo[im.f];arr.push(typeof fn==='function'?fn:function(){return 0;});}"
@"window.__revwasm_imports[instId]=arr;}"
@"function Module(bytes){this._b=b64(bytes);}"
@"function Instance(module,importObject){"
@"var b=(module&&module._b!==undefined)?module._b:b64(module);"
@"var r=call({cmd:'instantiate',bytes:b});"
@"if(!r.ok)throw new Error(r.err);"
@"if(r.imports&&r.imports.length)registerImports(r.instance,r.imports,importObject);"
@"this.exports=makeInstance(r.instance).exports;}"
@"function instantiate(bytes,importObject){return new Promise(function(res,rej){"
@"var r=call({cmd:'instantiate',bytes:b64(bytes)});"
@"if(!r.ok){rej(new Error(r.err));return;}"
@"if(r.imports&&r.imports.length)registerImports(r.instance,r.imports,importObject);"
@"var inst=makeInstance(r.instance);"
@"res((bytes&&bytes._b!==undefined)?inst:{module:{},instance:inst});});}"
@"function compile(bytes){return Promise.resolve(new Module(bytes));}"
@"function validate(bytes){var r=call({cmd:'validate',bytes:b64(bytes)});return !!r.ok;}"
@"window.WebAssembly={instantiate:instantiate,compile:compile,validate:validate,Module:Module,"
@"Instance:function(){throw new Error('sync Instance unsupported');}};"
@"})();";

@implementation RevWasm

+ (void)installInWebView:(WebView *)webView forFrame:(WebFrame *)frame {
    RevWasmHost *host = [[RevWasmHost alloc] init];
    host->_webView = webView;
    [[(id)webView windowScriptObject] setValue:host forKey:@"__revwasm"];
    [host release];
    [(id)webView stringByEvaluatingJavaScriptFromString:kRevWasmBootstrap];
}

@end
