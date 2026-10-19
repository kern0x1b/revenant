#include <libxml/parser.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#include <string.h>

int main(void)
{
    static const char sheet[] =
        "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\">"
        "<xsl:output method=\"text\"/><xsl:template match=\"/\">"
        "<xsl:for-each select=\"//i\"><xsl:sort select=\".\" order=\"descending\"/><xsl:value-of select=\".\"/>"
        "</xsl:for-each></xsl:template></xsl:stylesheet>";
    static const char source[] = "<l><i>b</i><i>a</i><i>c</i></l>";
    xsltStylesheetPtr stylesheet = xsltParseStylesheetDoc(xmlReadMemory(sheet, sizeof(sheet) - 1, "s.xsl", NULL, 0));
    xmlDocPtr input = xmlReadMemory(source, sizeof(source) - 1, "l.xml", NULL, 0);
    xmlDocPtr result = stylesheet && input ? xsltApplyStylesheet(stylesheet, input, NULL) : NULL;
    xmlChar *text = NULL;
    int length = 0;
    int ok = result && !xsltSaveResultToString(&text, &length, result, stylesheet)
        && length == 3 && !memcmp(text, "cba", 3);
    xmlFree(text);
    xmlFreeDoc(result);
    xmlFreeDoc(input);
    xsltFreeStylesheet(stylesheet);
    return ok ? 0 : 1;
}
