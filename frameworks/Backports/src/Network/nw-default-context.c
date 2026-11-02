#include <stddef.h>

extern void *nw_content_context_create(const char *context_identifier);

__attribute__((visibility("default"))) void *_nw_content_context_default_message = NULL;

__attribute__((constructor)) static void revenant_nw_default_message_init(void)
{
    _nw_content_context_default_message = nw_content_context_create("Default Message");
}
