#import <Foundation/Foundation.h>
#include <cstdio>
#include <cstring>
#include <exception>
#include <functional>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <vector>

#include <objc/message.h>
#include <objc/runtime.h>

namespace {

__attribute__((noinline)) void host(const char *name)
{
    Class thrower = NSClassFromString(@"XLHostThrower");
    ((void (*)(id, SEL))objc_msgSend)((id)thrower, sel_registerName(name));
}

int destroyed;
int live;
char order[64];
unsigned order_length;

void note(char tag)
{
    if (order_length + 1 < sizeof order) {
        order[order_length++] = tag;
        order[order_length] = 0;
    }
}

void forget()
{
    order_length = 0;
    order[0] = 0;
    destroyed = 0;
}

void report(const char *name, bool ok)
{
    printf("%s %s\n", ok ? "ok" : "FAIL", name);
}


struct Payload {
    long a;
    double b;
    char tag[16];
    Payload(long a_, double b_, const char *t) : a(a_), b(b_)
    {
        memset(tag, 0, sizeof tag);
        strncpy(tag, t, sizeof tag - 1);
    }
    bool same(const Payload &other) const { return a == other.a && b == other.b && strcmp(tag, other.tag) == 0; }
};

struct A {
    int a = 1;
    virtual ~A() {}
};
struct B : A {
    int b = 2;
};
struct C : B {
    int c = 3;
};

struct M1 {
    int m1 = 10;
    virtual ~M1() {}
};
struct M2 {
    int m2 = 20;
    virtual ~M2() {}
};
struct D : M1, M2 {
    int d = 30;
};

struct VB {
    int vb = 5;
    virtual ~VB() {}
};
struct V1 : virtual VB {
    int v1 = 6;
};
struct V2 : virtual VB {
    int v2 = 7;
};
struct VD : V1, V2 {
    int vd = 8;
};

struct Counted {
    int id;
    explicit Counted(int i) : id(i) { ++live; }
    Counted(const Counted &other) : id(other.id) { ++live; }
    ~Counted() { --live; }
};

struct Guard {
    char tag;
    explicit Guard(char t) : tag(t) {}
    ~Guard()
    {
        ++destroyed;
        note(tag);
    }
};

struct Unwinding {
    int *seen;
    explicit Unwinding(int *s) : seen(s) {}
    ~Unwinding() { *seen = std::uncaught_exceptions(); }
};

struct Thrower {
    Thrower() { throw 17; }
};

struct Holder {
    Guard first;
    Thrower second;
    Guard third;
    Holder() : first('f'), third('t') {}
};

struct Tagged {
    int id;
    const Tagged *self;
    explicit Tagged(int i) : id(i), self(this) {}
    Tagged(const Tagged &other) : id(other.id), self(this) {}
};

__attribute__((noinline)) void throw_int(int value)
{
    Guard guard('i');
    throw value;
}

__attribute__((noinline)) void deep(int depth, int value)
{
    Guard guard(static_cast<char>('a' + depth));
    if (depth == 0) {
        throw_int(value);
    }
    deep(depth - 1, value);
}

__attribute__((noinline)) void throw_c()
{
    throw C();
}

__attribute__((noinline)) void throw_d()
{
    throw D();
}

__attribute__((noinline)) void throw_vd()
{
    throw VD();
}

__attribute__((noinline)) void throw_runtime(const char *text)
{
    throw std::runtime_error(text);
}

__attribute__((noinline)) void inner_rethrow()
{
    try {
        throw Tagged(5);
    } catch (...) {
        throw;
    }
}

__attribute__((noinline)) void middle_rethrow()
{
    try {
        inner_rethrow();
    } catch (const Tagged &) {
        throw;
    }
}

}

@interface LibCxxExceptions : NSObject
@end

@implementation LibCxxExceptions

- (void)stepValue
{
    int integer = 0;
    try {
        throw 42;
    } catch (int value) {
        integer = value;
    }
    report("value.int", integer == 42);

    const char *text = nullptr;
    try {
        throw "text";
    } catch (const char *value) {
        text = value;
    }
    report("value.pointer", text && strcmp(text, "text") == 0);

    std::string owned;
    try {
        throw std::string("owned by the exception");
    } catch (const std::string &value) {
        owned = value;
    }
    report("value.string", owned == "owned by the exception");

    int mask = 0;
    try {
        throw 3.5;
    } catch (double value) {
        mask |= value == 3.5 ? 1 : 0;
    }
    try {
        throw 'c';
    } catch (char value) {
        mask |= value == 'c' ? 2 : 0;
    }
    try {
        throw 7L;
    } catch (long value) {
        mask |= value == 7L ? 4 : 0;
    }
    try {
        throw static_cast<unsigned short>(9);
    } catch (unsigned short value) {
        mask |= value == 9 ? 8 : 0;
    }
    try {
        throw true;
    } catch (bool value) {
        mask |= value ? 16 : 0;
    }
    report("value.fundamental", mask == 31);

    Payload sent(123456789L, 2.25, "payload");
    bool copied = false, referenced = false, pointed = false;
    try {
        throw sent;
    } catch (Payload value) {
        copied = value.same(sent);
    }
    try {
        throw sent;
    } catch (const Payload &value) {
        referenced = value.same(sent) && &value != &sent;
    }
    Payload *heap = new Payload(5, 6.5, "heap");
    try {
        throw heap;
    } catch (Payload *value) {
        pointed = value == heap && value->same(*heap);
    }
    delete heap;
    report("value.struct", copied);
    report("value.reference", referenced);
    report("value.pointer.class", pointed);

    int which = 0;
    try {
        throw 1;
    } catch (long) {
        which = 1;
    } catch (int) {
        which = 2;
    }
    report("value.exact", which == 2);
}

- (void)stepHierarchy
{
    int found = 0;
    try {
        throw_c();
    } catch (const A &value) {
        found = value.a == 1 ? 1 : -1;
    }
    report("hier.base", found == 1);

    found = 0;
    try {
        throw_c();
    } catch (const B &value) {
        found = value.b == 2 ? 1 : -1;
    }
    report("hier.middle", found == 1);

    found = 0;
    try {
        throw_c();
    } catch (const C &value) {
        found = value.c == 3 && value.b == 2 && value.a == 1 ? 1 : -1;
    }
    report("hier.exact", found == 1);

    found = 0;
    try {
        throw_c();
    } catch (A value) {
        found = value.a == 1 ? 1 : -1;
    }
    report("hier.sliced", found == 1);

    found = 0;
    try {
        throw_d();
    } catch (const M2 &value) {
        found = value.m2 == 20 ? 1 : -1;
    }
    report("hier.multiple", found == 1);

    found = 0;
    try {
        throw_d();
    } catch (const M1 &value) {
        found = value.m1 == 10 ? 1 : -1;
    }
    report("hier.multiple.first", found == 1);

    found = 0;
    try {
        throw_vd();
    } catch (const VB &value) {
        found = value.vb == 5 ? 1 : -1;
    }
    report("hier.virtual", found == 1);

    found = 0;
    try {
        throw_vd();
    } catch (const V2 &value) {
        found = value.v2 == 7 && value.vb == 5 ? 1 : -1;
    }
    report("hier.virtual.sibling", found == 1);

    found = 0;
    try {
        throw_c();
    } catch (const M1 &) {
        found = -1;
    } catch (...) {
        found = 1;
    }
    report("hier.nomatch", found == 1);
}

- (void)stepStandard
{
    std::string what;
    try {
        throw_runtime("boom");
    } catch (const std::exception &error) {
        what = error.what();
    }
    report("std.what", what == "boom");

    int path = 0;
    try {
        try {
            throw_runtime("not a logic error");
        } catch (const std::logic_error &) {
            path = -1;
        }
    } catch (const std::runtime_error &error) {
        path = strcmp(error.what(), "not a logic error") == 0 ? 1 : -2;
    }
    report("std.sibling", path == 1);

    std::vector<int> items{1, 2, 3};
    path = 0;
    try {
        (void)items.at(9);
    } catch (const std::out_of_range &) {
        path = 1;
    }
    report("std.out_of_range", path == 1);

    path = 0;
    try {
        (void)items.at(9);
    } catch (const std::logic_error &) {
        path = 1;
    }
    report("std.logic_error", path == 1);

    path = 0;
    try {
        std::string text("abc");
        (void)text.at(5);
    } catch (const std::exception &error) {
        path = strlen(error.what()) > 0 ? 1 : -1;
    }
    report("std.string.at", path == 1);

    path = 0;
    try {
        std::function<int()> empty;
        (void)empty();
    } catch (const std::bad_function_call &) {
        path = 1;
    }
    report("std.bad_function_call", path == 1);

    path = 0;
    try {
        B base;
        A &reference = base;
        (void)dynamic_cast<C &>(reference);
    } catch (const std::bad_cast &) {
        path = 1;
    }
    report("std.bad_cast", path == 1);

    path = 0;
    try {
        throw std::invalid_argument("argument");
    } catch (const std::exception &error) {
        path = typeid(error) == typeid(std::invalid_argument) ? 1 : -1;
    }
    report("std.typeid", path == 1);
}

- (void)stepNested
{
    std::string text;
    try {
        try {
            throw 1;
        } catch (int) {
            throw std::string("inner to outer");
        }
    } catch (const std::string &value) {
        text = value;
    }
    report("nested.other", text == "inner to outer");

    int id = 0;
    bool same = false;
    try {
        middle_rethrow();
    } catch (const Tagged &value) {
        id = value.id;
        same = true;
    }
    report("nested.rethrow", same && id == 5);

    int depth = 0;
    try {
        try {
            try {
                throw 7;
            } catch (...) {
                ++depth;
                throw;
            }
        } catch (...) {
            ++depth;
            throw;
        }
    } catch (int value) {
        depth += value;
    }
    report("nested.catchall.rethrow", depth == 9);

    int inside = 0;
    try {
        throw 1;
    } catch (int) {
        try {
            throw 2;
        } catch (int second) {
            inside += second;
        }
        try {
            throw std::runtime_error("second");
        } catch (const std::exception &) {
            inside += 10;
        }
    }
    report("nested.inside.handler", inside == 12);

    int uncaught_during = -1, uncaught_after = -1;
    try {
        Unwinding probe(&uncaught_during);
        throw 3;
    } catch (int) {
        uncaught_after = std::uncaught_exceptions();
    }
    report("nested.uncaught", uncaught_during == 1 && uncaught_after == 0 && std::uncaught_exceptions() == 0);
}

- (void)stepUnwind
{
    forget();
    int caught = 0;
    try {
        deep(3, 11);
    } catch (int value) {
        caught = value;
    }
    report("unwind.value", caught == 11);
    report("unwind.destructors", destroyed == 5);
    report("unwind.order", strcmp(order, "iabcd") == 0);

    forget();
    int constructor = 0;
    try {
        Holder holder;
    } catch (int value) {
        constructor = value;
    }
    report("unwind.constructor", constructor == 17 && destroyed == 1 && strcmp(order, "f") == 0);

    live = 0;
    try {
        throw Counted(4);
    } catch (Counted copy) {
        report("unwind.copy.live", live >= 1 && copy.id == 4);
    }
    report("unwind.copy.released", live == 0);

    live = 0;
    try {
        try {
            throw Counted(8);
        } catch (const Counted &) {
            throw;
        }
    } catch (const Counted &value) {
        report("unwind.rethrow.live", live == 1 && value.id == 8);
    }
    report("unwind.rethrow.released", live == 0);

    forget();
    for (int round = 0; round < 200; ++round) {
        try {
            Guard guard('x');
            throw round;
        } catch (int value) {
            if (value != round) {
                destroyed = -1000;
            }
        }
    }
    report("unwind.loop", destroyed == 200);
}

- (void)stepPointer
{
    std::exception_ptr pointer;
    try {
        throw std::runtime_error("kept");
    } catch (...) {
        pointer = std::current_exception();
    }
    report("ptr.current", static_cast<bool>(pointer));

    std::string what;
    try {
        std::rethrow_exception(pointer);
    } catch (const std::runtime_error &error) {
        what = error.what();
    }
    report("ptr.rethrow", what == "kept");

    std::exception_ptr copy = pointer;
    pointer = nullptr;
    bool null_now = !pointer && copy != pointer;
    what.clear();
    try {
        std::rethrow_exception(copy);
    } catch (const std::exception &error) {
        what = error.what();
    }
    report("ptr.copy", null_now && what == "kept");

    live = 0;
    {
        std::exception_ptr made;
        try {
            throw Counted(3);
        } catch (...) {
            made = std::current_exception();
        }
        int id = 0;
        try {
            std::rethrow_exception(made);
        } catch (const Counted &value) {
            id = value.id;
        }
        report("ptr.object", id == 3 && live == 1);
    }
    report("ptr.released", live == 0);

    std::exception_ptr same_a, same_b;
    try {
        throw 5;
    } catch (...) {
        same_a = std::current_exception();
        same_b = std::current_exception();
    }
    report("ptr.equal", same_a == same_b && !(same_a != same_b));

    int depth = 0;
    try {
        try {
            throw std::runtime_error("inner");
        } catch (...) {
            std::throw_with_nested(std::logic_error("outer"));
        }
    } catch (const std::logic_error &error) {
        depth = strcmp(error.what(), "outer") == 0 ? 1 : -1;
        try {
            std::rethrow_if_nested(error);
        } catch (const std::runtime_error &nested) {
            depth += strcmp(nested.what(), "inner") == 0 ? 10 : -10;
        }
    }
    report("ptr.nested", depth == 11);
}

- (void)stepForeign
{
    int path = 0;
    forget();
    try {
        Guard guard('s');
        host("throwStandard");
    } catch (const std::logic_error &) {
        path = -1;
    } catch (...) {
        path = 1;
    }
    report("foreign.standard", path == 1 && destroyed == 1);

    path = 0;
    try {
        host("throwInteger");
    } catch (int value) {
        path = value == 41 ? 1 : -2;
    } catch (...) {
        path = -1;
    }
    report("foreign.integer", path == 1);

    path = 0;
    forget();
    try {
        Guard guard('o');
        host("throwObjC");
    } catch (...) {
        path = 1;
    }
    report("foreign.objc", path == 1 && destroyed == 1);

    path = 0;
    try {
        try {
            host("throwCustom");
        } catch (...) {
            throw;
        }
    } catch (...) {
        path = 1;
    }
    report("foreign.rethrow", path == 1);

    std::exception_ptr pointer;
    try {
        host("throwStandard");
    } catch (...) {
        pointer = std::current_exception();
    }
    path = 0;
    try {
        std::rethrow_exception(pointer);
    } catch (...) {
        path = 1;
    }
    report("foreign.pointer", static_cast<bool>(pointer) && path == 1);
}

- (void)stepRoundTrip
{
    int caught = 0;
    forget();
    try {
        [@[@1, @2] enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
            Guard guard('b');
            throw Payload(77, 1.5, "via the host");
        }];
    } catch (const Payload &value) {
        caught = value.a == 77 && strcmp(value.tag, "via the host") == 0 ? 1 : -1;
    }
    report("roundtrip.guest.host.guest", caught == 1 && destroyed == 1);

    caught = 0;
    try {
        [@[@1] enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
            throw std::runtime_error("block");
        }];
    } catch (const std::exception &error) {
        caught = strcmp(error.what(), "block") == 0 ? 1 : -1;
    }
    report("roundtrip.standard", caught == 1);
}

- (void)stepEscape
{
    throw Payload(9, 0.5, "escaped");
}

- (void)stepEscapeInteger
{
    throw 42;
}

- (void)stepEscapeStandard
{
    throw std::runtime_error("escaped standard");
}

@end
