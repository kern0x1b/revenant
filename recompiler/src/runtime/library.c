#include "xl_guest_image.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/getsect.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>

extern const struct mach_header _mh_dylib_header;
extern const struct xl_guest_slot xl_guest_slots[];
extern const uint32_t xl_guest_slot_count;
extern void xl_run_initializers(void);
extern void xl_install_diagnostics(void);
_Noreturn void xl_unsupported(const char *message);

enum { XL_LIBRARY_IDLE, XL_LIBRARY_ATTACHED, XL_LIBRARY_FAILED, XL_LIBRARY_READY };

static pthread_mutex_t xl_library_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_t xl_library_owner;
static int xl_library_state;
static int xl_library_failure;

static int xl_library_reserved(uint32_t low, uint32_t high)
{
    vm_address_t cursor = low;
    while (cursor < high) {
        vm_address_t address = cursor;
        vm_size_t size = 0;
        vm_region_extended_info_data_t info;
        mach_msg_type_number_t count = VM_REGION_EXTENDED_INFO_COUNT;
        mach_port_t object;
        if (vm_region_64(mach_task_self(), &address, &size, VM_REGION_EXTENDED_INFO, (vm_region_info_t)&info, &count, &object) != KERN_SUCCESS ||
            address > cursor || info.protection != VM_PROT_NONE || info.pages_resident != 0)
            return 0;
        cursor = address + size;
    }
    return 1;
}

static int xl_library_format(const struct xl_guest_header *header, unsigned long size)
{
    if (size < sizeof *header || header->magic != XL_GUEST_MAGIC || header->version != XL_GUEST_VERSION)
        return 0;
    if (header->low >= header->high || header->low % XL_GUEST_GRANULE || header->high % XL_GUEST_GRANULE)
        return 0;
    if (header->segment_count > (size - sizeof *header) / sizeof(struct xl_guest_segment))
        return 0;
    const struct xl_guest_segment *segments = (const struct xl_guest_segment *)(header + 1);
    for (uint32_t index = 0; index < header->segment_count; index++) {
        const struct xl_guest_segment *segment = &segments[index];
        if (segment->address < header->low || segment->size > header->high - segment->address || segment->address % XL_GUEST_GRANULE ||
            segment->size % XL_GUEST_GRANULE || segment->offset % XL_GUEST_GRANULE || segment->length % XL_GUEST_GRANULE ||
            segment->length > segment->size || segment->offset > size || segment->length > size - segment->offset)
            return 0;
    }
    for (uint32_t index = 0; index < xl_guest_slot_count; index++) {
        uint32_t address = xl_guest_slots[index].address;
        if (address < header->low || header->high - address < sizeof(uint32_t))
            return 0;
    }
    return 1;
}

static int xl_library_attach(void)
{
    unsigned long size = 0;
    const struct xl_guest_header *header = (const struct xl_guest_header *)getsectiondata(&_mh_dylib_header, XL_GUEST_SEGMENT, XL_GUEST_SECTION, &size);
    const struct section *section = getsectbynamefromheader(&_mh_dylib_header, XL_GUEST_SEGMENT, XL_GUEST_SECTION);
    Dl_info info;
    if (!header || !section || !dladdr(&_mh_dylib_header, &info) || !info.dli_fname || !xl_library_format(header, size))
        return XL_LIBRARY_BAD_FORMAT;
    if (!xl_library_reserved(header->low, header->high))
        return XL_LIBRARY_NOT_RESERVED;
    int file = open(info.dli_fname, O_RDONLY);
    if (file < 0)
        return XL_LIBRARY_MAP_FAILED;
    const struct xl_guest_segment *segments = (const struct xl_guest_segment *)(header + 1);
    int status = XL_LIBRARY_OK;
    for (uint32_t index = 0; index < header->segment_count && status == XL_LIBRARY_OK; index++) {
        const struct xl_guest_segment *segment = &segments[index];
        if (segment->length && mmap((void *)(uintptr_t)segment->address, segment->length, PROT_READ | PROT_WRITE, MAP_FIXED | MAP_PRIVATE, file,
                                    section->offset + segment->offset) != (void *)(uintptr_t)segment->address)
            status = XL_LIBRARY_MAP_FAILED;
        else if (segment->size > segment->length &&
                 vm_protect(mach_task_self(), segment->address + segment->length, segment->size - segment->length, FALSE, VM_PROT_READ | VM_PROT_WRITE) != KERN_SUCCESS)
            status = XL_LIBRARY_MAP_FAILED;
    }
    close(file);
    if (status != XL_LIBRARY_OK)
        return status;
    for (uint32_t index = 0; index < xl_guest_slot_count; index++)
        *(volatile uint32_t *)(uintptr_t)xl_guest_slots[index].address = xl_guest_slots[index].value;
    for (uint32_t index = 0; index < header->segment_count; index++) {
        const struct xl_guest_segment *segment = &segments[index];
        if (segment->protection != (XL_GUEST_READ | XL_GUEST_WRITE) &&
            vm_protect(mach_task_self(), segment->address, segment->size, FALSE, (vm_prot_t)segment->protection) != KERN_SUCCESS)
            return XL_LIBRARY_MAP_FAILED;
    }
    return XL_LIBRARY_OK;
}

void xl_library_ensure(void)
{
    if (__atomic_load_n(&xl_library_state, __ATOMIC_ACQUIRE) == XL_LIBRARY_READY)
        return;
    if (pthread_equal(__atomic_load_n(&xl_library_owner, __ATOMIC_RELAXED), pthread_self()))
        return;
    pthread_mutex_lock(&xl_library_lock);
    if (xl_library_state == XL_LIBRARY_IDLE) {
        pthread_mutex_unlock(&xl_library_lock);
        xl_unsupported("the guest image of the translated library is not attached: it must be loaded with xl_load");
    }
    if (xl_library_state == XL_LIBRARY_FAILED) {
        pthread_mutex_unlock(&xl_library_lock);
        xl_unsupported("the guest image of the translated library could not be attached");
    }
    if (xl_library_state == XL_LIBRARY_ATTACHED) {
        __atomic_store_n(&xl_library_owner, pthread_self(), __ATOMIC_RELAXED);
        xl_run_initializers();
        __atomic_store_n(&xl_library_state, XL_LIBRARY_READY, __ATOMIC_RELEASE);
        __atomic_store_n(&xl_library_owner, NULL, __ATOMIC_RELAXED);
    }
    pthread_mutex_unlock(&xl_library_lock);
}

int xl_library_init(void)
{
    pthread_mutex_lock(&xl_library_lock);
    if (xl_library_state == XL_LIBRARY_IDLE) {
        xl_library_failure = xl_library_attach();
        xl_library_state = xl_library_failure == XL_LIBRARY_OK ? XL_LIBRARY_ATTACHED : XL_LIBRARY_FAILED;
    }
    int failure = xl_library_failure;
    pthread_mutex_unlock(&xl_library_lock);
    if (failure == XL_LIBRARY_OK)
        xl_library_ensure();
    return failure;
}

void xl_library_diagnostics(void)
{
    xl_install_diagnostics();
}
