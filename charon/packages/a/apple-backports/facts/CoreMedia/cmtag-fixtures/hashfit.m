// CMTagHash: the coordinator's bounded candidate set, evaluated against the host in C, because
// CFHash cannot be reproduced in Python and every candidate that involves it has to run here.
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static CMTag mk(long cat, unsigned type, unsigned long long v){ CMTag t; t.category=(CMTagCategory)cat; t.dataType=(CMTagDataType)type; t.value=v; return t; }

static unsigned long long c_xor_lo(CMTag t){ return (unsigned long long)((unsigned)t.category ^ (unsigned)t.dataType ^ (unsigned)t.value); }
static unsigned long long c_xor_hi(CMTag t){ return (unsigned long long)((unsigned)t.category ^ (unsigned)t.dataType ^ (unsigned)(t.value >> 32)); }
static unsigned long long c_xor_all(CMTag t){ return (unsigned long long)((unsigned)t.category ^ (unsigned)t.dataType ^ (unsigned)t.value ^ (unsigned)(t.value>>32)); }

static unsigned long long c_mul31(CMTag t){
    unsigned char b[16]; memcpy(b,&t,16); unsigned long long h=0;
    for (int i=0;i<16;i++) h = h*31 + b[i]; return h; }
static unsigned long long c_mul33(CMTag t){
    unsigned char b[16]; memcpy(b,&t,16); unsigned long long h=0;
    for (int i=0;i<16;i++) h = h*33 + b[i]; return h; }
static unsigned long long c_fnv32(CMTag t){
    unsigned char b[16]; memcpy(b,&t,16); unsigned int h=2166136261u;
    for (int i=0;i<16;i++){ h ^= b[i]; h *= 16777619u; } return h; }
static unsigned long long c_fnv64(CMTag t){
    unsigned char b[16]; memcpy(b,&t,16); unsigned long long h=14695981039346656037ULL;
    for (int i=0;i<16;i++){ h ^= b[i]; h *= 1099511628211ULL; } return h; }

static unsigned long long c_cfhash_dict(CMTag t){
    const void *keys[] = { CFSTR("category"), CFSTR("dataType"), CFSTR("value") };
    CFNumberRef v[3];
    v[0]=CFNumberCreate(NULL,kCFNumberSInt32Type,&t.category);
    v[1]=CFNumberCreate(NULL,kCFNumberSInt32Type,&t.dataType);
    v[2]=CFNumberCreate(NULL,kCFNumberSInt64Type,&t.value);
    const void *vals[] = { v[0], v[1], v[2] };
    CFDictionaryRef d = CFDictionaryCreate(NULL,keys,vals,3,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    unsigned long long h = (unsigned long long)CFHash(d);
    CFRelease(d); CFRelease(v[0]); CFRelease(v[1]); CFRelease(v[2]);
    return h; }
static unsigned long long c_cfhash_num(CMTag t){
    CFNumberRef n = CFNumberCreate(NULL,kCFNumberSInt64Type,&t.value);
    unsigned long long h = (unsigned long long)CFHash(n); CFRelease(n); return h; }
static unsigned long long c_cfhash_cat(CMTag t){
    CFNumberRef n = CFNumberCreate(NULL,kCFNumberSInt32Type,&t.category);
    unsigned long long h = (unsigned long long)CFHash(n); CFRelease(n); return h; }

int main(void){
    struct { const char *label; CMTag t; } s[] = {
        { "invalid   0/0",        mk(0,0,0) },
        { "vide      mvid/OSType",mk(1835297121,2,'vide') },
        { "sint 7    trak/SInt64",mk(1953653099,3,7) },
        { "flags 3   flgs/Flags", mk(1885960294,5,3) },
        { "float 1.5 trak/Float64",mk(1953653099,4,0x3FF8000000000000ULL) },
        { "float 0.0 trak/Float64",mk(1953653099,4,0) },
    };
    unsigned n = sizeof(s)/sizeof(s[0]);
    printf("%-24s %-14s %-14s %-14s %-14s %-14s %-14s %-14s %-14s %-14s\n",
        "tag","HOST","xor_lo","xor_hi","xor_all","mul31","mul33","fnv32","fnv64","dict","num");
    for (unsigned i=0;i<n;i++){
        printf("%-24s %-14llu %-14llu %-14llu %-14llu %-14llu %-14llu %-14llu %-14llu %-14llu %-14llu\n",
            s[i].label, (unsigned long long)CMTagHash(s[i].t),
            c_xor_lo(s[i].t), c_xor_hi(s[i].t), c_xor_all(s[i].t),
            c_mul31(s[i].t), c_mul33(s[i].t), c_fnv32(s[i].t), c_fnv64(s[i].t),
            c_cfhash_dict(s[i].t), c_cfhash_num(s[i].t));
    }
    // the self-check: a candidate that cannot tell two tags apart is not a hash of the tag
    printf("\nself-check: does the candidate separate the pair that differs only in data type and value?\n");
    printf("  host %llu vs %llu -> %s\n", (unsigned long long)CMTagHash(s[2].t), (unsigned long long)CMTagHash(s[4].t),
        CMTagHash(s[2].t)!=CMTagHash(s[4].t) ? "distinguished" : "COLLIDES");
    unsigned long long (*cands[])(CMTag) = { c_xor_lo, c_xor_hi, c_xor_all, c_mul31, c_mul33, c_fnv32, c_fnv64, c_cfhash_dict, c_cfhash_num };
    const char *names[] = { "xor_lo","xor_hi","xor_all","mul31","mul33","fnv32","fnv64","cfhash_dict","cfhash_num" };
    for (unsigned k=0;k<sizeof(cands)/sizeof(cands[0]);k++){
        unsigned distinct = 1;
        for (unsigned i=0;i<n;i++) for (unsigned j=i+1;j<n;j++) if (cands[k](s[i].t)==cands[k](s[j].t)) distinct = 0;
        unsigned long long h0 = cands[k](s[0].t);
        unsigned long long h2 = cands[k](s[2].t);
        printf("  %-12s %s   (invalid %llu, sint7 %llu)\n", names[k], distinct ? "distinguishes all 6" : "COLLIDES", h0, h2);
    }
    return 0;
}
