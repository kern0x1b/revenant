#pragma once

#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface XLGuestBlock : NSObject
+ (instancetype)holderWithGuestBlock:(uint64_t)guest;
@property (nonatomic, readonly) uint64_t guestBlock;
@end

id objc_msgSendSuper2(struct objc_super *super, SEL selector, ...);
void objc_msgSendSuper2_stret(struct objc_super *super, SEL selector, ...);
void xl_manual_fast_enumeration(void *pack);
void xl_manual_init_with_format_arguments(void *pack);
void xl_manual__tlv_bootstrap(void *pack);
uint64_t xl_host_block_wrap(id block, uint32_t invoke, uint32_t descriptor);
void xl_unsupported_imp(id self, SEL selector);
id xl_format_string_with_format(id self, SEL selector, id format, va_list arguments);
id xl_format_init_with_format(id self, SEL selector, id format, va_list arguments);
void xl_format_append_format(id self, SEL selector, id format, va_list arguments);

struct xl_method_t {
    SEL name;
    const char *types;
    IMP imp;
};

struct xl_ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    uint32_t alignment;
    uint32_t size;
};

struct xl_property_t {
    const char *name;
    const char *attributes;
};

struct xl_class_ro_t {
    uint32_t flags;
    uint32_t instance_start;
    uint32_t instance_size;
    const uint8_t *ivar_layout;
    const char *name;
    void *base_methods;
    void *base_protocols;
    void *ivars;
    const uint8_t *weak_ivar_layout;
    void *base_properties;
};

struct xl_ivar_fixup {
    int32_t *offset_var;
    uint32_t guest_offset;
};

struct xl_class_layout {
    struct xl_class_ro_t *ro;
    uint32_t address;
    const char *super_host;
    uint32_t super_guest;
    uint32_t guest_instance_start;
    uint32_t guest_instance_size;
    uint32_t ivar_count;
    const struct xl_ivar_fixup *ivars;
};

struct xl_category_t {
    const char *name;
    Class cls;
    void *instance_methods;
    void *class_methods;
    void *protocols;
    void *instance_properties;
};

// Guest class objects in the arm64 layout and the host shadow classes that stand for them (swift_classes.m).
void xl_shadow_init(void);
Class xl_class_in(uint64_t guest);
uint64_t xl_class_out(uintptr_t host);
Class xl_class_of(id object);
uint32_t xl_shadow_imp(IMP imp);
int xl_guest_send(id object, SEL selector, uint64_t *result);
uint32_t xl_guest_imp_address(IMP imp);
int xl_shadow_log_enabled(void);
void xl_shadow_note(const char *format, ...);
void xl_shadow_register_listed(void);
