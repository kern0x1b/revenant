#include <plist/plist.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
    plist_t dictionary = plist_new_dict();
    plist_dict_set_item(dictionary, "CFBundleIdentifier", plist_new_string("org.example.demo"));
    char *xml = NULL;
    uint32_t length = 0;
    plist_to_xml(dictionary, &xml, &length);
    plist_t parsed = NULL;
    plist_from_xml(xml, length, &parsed);
    const char *read = plist_get_string_ptr(plist_dict_get_item(parsed, "CFBundleIdentifier"), NULL);
    int failed = !read || strcmp(read, "org.example.demo") != 0;
    plist_mem_free(xml);
    plist_free(parsed);
    plist_free(dictionary);
    return failed;
}
