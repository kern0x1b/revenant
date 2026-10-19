#include <libxml/parser.h>
#include <libxml/tree.h>
#include <string.h>

int main(void)
{
    static const char document[] = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><r a=\"1\"><c>\xe9</c></r>";
    xmlDocPtr doc = xmlReadMemory(document, sizeof(document) - 1, "test.xml", NULL, XML_PARSE_NONET);
    if (!doc)
        return 1;
    xmlNodePtr root = xmlDocGetRootElement(doc);
    xmlChar *text = root && root->children ? xmlNodeGetContent(root->children) : NULL;
    int ok = text && !strcmp((const char *)text, "\xc3\xa9");
    xmlFree(text);
    xmlFreeDoc(doc);
    return ok ? 0 : 1;
}
