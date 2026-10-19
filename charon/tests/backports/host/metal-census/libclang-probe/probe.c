/* libclang's cursor children, walked from C, against the same translation unit probe.py walks.
 *
 * Built on demand by probe.py into .agent-work/runs/metal-census/; never into the checkout. The
 * libclang C API is declared here by hand because this machine has no clang-c/Index.h - there is
 * none under /Library/Developer/CommandLineTools, and no Xcode - so the probe carries the six
 * declarations it needs rather than pulling a header it cannot find.
 *
 * The point of the C side is that it rules a cause out. The likeliest reason a visitor never fires
 * through ctypes on arm64 is a CXCursor whose layout does not match clang-c/Index.h, since the
 * struct is 32 bytes and is passed by value. So this file prints sizeof and the three offsets, and
 * the claim under test is that they agree with ctypes AND that the children are still zero.
 */
#include <stddef.h>
#include <stdio.h>

typedef struct { int kind; int xdata; const void *data[3]; } CXCursor;
typedef struct { const void *begin[2]; unsigned begin_int, end_int; } CXSourceRange;
typedef void *CXIndex;
typedef void *CXTranslationUnit;
typedef void *CXToken;

extern CXIndex clang_createIndex(int excludeDeclarationsFromPCH, int displayDiagnostics);
extern CXTranslationUnit clang_parseTranslationUnit(CXIndex, const char *source,
                                                     const char *const *args, int count,
                                                     void *unsaved, unsigned num_unsaved,
                                                     unsigned options);
extern unsigned clang_visitChildren(CXTranslationUnit, int (*)(CXCursor, CXCursor, void *), void *);
extern CXCursor clang_getTranslationUnitCursor(CXTranslationUnit);
extern CXSourceRange clang_getCursorExtent(CXCursor);
extern void clang_tokenize(CXTranslationUnit, CXSourceRange, void **, unsigned *);
extern const char *clang_getTokenSpelling(CXToken, unsigned *, unsigned *);
extern const char *clang_getCursorSpelling(CXCursor);
extern const char *clang_getCursorKindSpelling(int);
extern unsigned clang_getNumDiagnostics(CXTranslationUnit);

static int visited;

static int on_child(CXCursor cursor, CXCursor parent, void *data)
{
	(void)parent;
	(void)data;
	visited++;
	printf("      child %s %s\n", clang_getCursorKindSpelling(cursor.kind),
	       clang_getCursorSpelling(cursor));
	return 2; /* CXChildVisit_Continue */
}
int main(int argc, char **argv)
{
	CXTranslationUnit unit;
	CXToken tokens[256];
	unsigned number = 0;
	/* the file comes from argv, because a hand-built binary run from another directory otherwise
	 * names a file that is not there and reports no translation unit at all - which reads like a
	 * broken libclang rather than like a missing argument */
	const char *source = argc > 1 ? argv[1] : "decl.m";

	setvbuf(stdout, NULL, _IONBF, 0);
	printf("sizeof(CXCursor) %zu  offsetof kind %zu xdata %zu data %zu (C)\n",
	       sizeof(CXCursor), offsetof(CXCursor, kind), offsetof(CXCursor, xdata),
	       offsetof(CXCursor, data));

	unit = clang_parseTranslationUnit(clang_createIndex(0, 0), source, NULL, 0, NULL, 0, 0);
	if (!unit) {
		printf("no translation unit for %s\n", source);
		return 1;
	}
	clang_tokenize(unit, clang_getCursorExtent(clang_getTranslationUnitCursor(unit)),
	               tokens, &number);
	visited = 0;
	clang_visitChildren(unit, on_child, NULL);
	printf("C          diagnostics %u  tokens %u  children %d\n",
	       clang_getNumDiagnostics(unit), number, visited);
	return 0;
}
