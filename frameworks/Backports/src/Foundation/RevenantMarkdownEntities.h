#import <Foundation/Foundation.h>

typedef struct {
    const char *name;
    unsigned first;
    unsigned second;
} RevenantMarkdownEntity;

const RevenantMarkdownEntity *RevenantMarkdownEntityNamed(const char *name, size_t length);
