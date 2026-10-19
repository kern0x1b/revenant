#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "RevenantMLProto.h"
#include "RevenantMLWrite.h"
static unsigned char *slurp(const char *path, size_t *length)
{
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); *length = (size_t)ftell(f); fseek(f, 0, SEEK_SET);
    unsigned char *bytes = malloc(*length);
    if (bytes && fread(bytes, 1, *length, f) != *length) { free(bytes); bytes = NULL; }
    fclose(f);
    return bytes;
}
int main(int argc, char **argv)
{
    size_t length = 0;
    unsigned char *bytes = slurp(argv[1], &length);
    revenant_ml_node doc, again;
    unsigned char *out = NULL; size_t outlen = 0;
    if (!bytes || !revenant_ml_read(&doc, bytes, length, "CoreML.Specification.Model")) { printf("read failed\n"); return 1; }
    if (!revenant_ml_write(&doc, &out, &outlen)) { printf("write failed\n"); return 1; }
    FILE *f = fopen(argv[2], "wb"); fwrite(out, 1, outlen, f); fclose(f);
    if (!revenant_ml_read(&again, out, outlen, "CoreML.Specification.Model")) { printf("re-read failed\n"); return 1; }
    printf("input %zu bytes, output %zu bytes; top fields %zu and %zu\n", length, outlen, revenant_ml_count(&doc), revenant_ml_count(&again));
    return revenant_ml_count(&doc) == revenant_ml_count(&again) ? 0 : 2;
}
