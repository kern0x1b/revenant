"""Writes the OpenGLES library of the backports: a function for every one OpenGL ES 3.0 added to the ES 2.0 header of an SDK,
answering through the extension iOS 6 has for it where there is one and with an error where there is not.

    python3 tests/backports/tools/gen-es3.py SDKROOT
"""
import json
import os
import re
import sys

FORWARDS = {
    "glBindVertexArray": "glBindVertexArrayOES", "glDeleteVertexArrays": "glDeleteVertexArraysOES",
    "glGenVertexArrays": "glGenVertexArraysOES", "glIsVertexArray": "glIsVertexArrayOES",
    "glGenQueries": "glGenQueriesEXT", "glDeleteQueries": "glDeleteQueriesEXT", "glIsQuery": "glIsQueryEXT",
    "glBeginQuery": "glBeginQueryEXT", "glEndQuery": "glEndQueryEXT", "glGetQueryiv": "glGetQueryivEXT",
    "glGetQueryObjectuiv": "glGetQueryObjectuivEXT",
    "glFenceSync": "glFenceSyncAPPLE", "glIsSync": "glIsSyncAPPLE", "glDeleteSync": "glDeleteSyncAPPLE",
    "glClientWaitSync": "glClientWaitSyncAPPLE", "glWaitSync": "glWaitSyncAPPLE", "glGetSynciv": "glGetSyncivAPPLE",
    "glGetInteger64v": "glGetInteger64vAPPLE",
    "glMapBufferRange": "glMapBufferRangeEXT", "glFlushMappedBufferRange": "glFlushMappedBufferRangeEXT",
    "glRenderbufferStorageMultisample": "glRenderbufferStorageMultisampleAPPLE",
    "glInvalidateFramebuffer": "glDiscardFramebufferEXT",
    "glTexStorage2D": "glTexStorage2DEXT", "glProgramParameteri": "glProgramParameteriEXT",
}
ALREADY = {"glDrawRangeElements", "glCompressedTexImage3D", "glCompressedTexSubImage3D", "glUnmapBuffer", "glGetBufferPointerv"}
# The query calls go to an object of their own: the OpenGLES of iOS 3.0 to 4.3.5 already exports these seven
# names, 5.0 to 6.1.6 does not, 7.0 does again, so they first appear in a release the rest of ES 3.0 does not,
# and one object holds the API of one release.
QUERIES = {"glGenQueries", "glDeleteQueries", "glIsQuery", "glBeginQuery", "glEndQuery", "glGetQueryiv", "glGetQueryObjectuiv"}

PROTOTYPE = re.compile(r"GL_API\s+([\w\s\*]+?)\s+GL_APIENTRY\s+(\w+)\s*\(([^;]*?)\)\s*(?:OPENGLES_\w+\([^;]*\))?\s*;")


def prototypes(path):
    text = open(path).read()
    found = {}
    for ret, name, params in PROTOTYPE.findall(text):
        found[name] = (" ".join(ret.split()), " ".join(params.split()))
    return found


def parameter_names(params):
    if params in ("void", ""):
        return []
    names = []
    for part in params.split(","):
        names.append(re.findall(r"\w+", part)[-1])
    return names


def write_functions(package, output, lines, newer, names):
    rows = []
    for name in names:
        ret, params = newer[name]
        lines.append("extern %s %s(%s) __attribute__((availability(ios, introduced=7.0)));" % (ret, name, params))
    lines.append("")
    for name in names:
        ret, params = newer[name]
        arguments = ", ".join(parameter_names(params))
        zero = "" if ret == "void" else "(%s)0" % ret if "*" not in ret else "NULL"
        if name in FORWARDS:
            target = FORWARDS[name]
            call = "fn(%s)" % arguments
            lines += ["%s %s(%s)" % (ret, name, params), "{",
                      "    static %s (*fn)(%s);" % (ret, params), "    if (!fn)",
                      '        fn = (%s (*)(%s))dlsym(RTLD_DEFAULT, "%s");' % (ret, params, target), "    if (fn)",
                      ("        { fn(%s); return; }" % arguments) if ret == "void" else ("        return fn(%s);" % arguments),
                      "    charon_es3_error();"] + ([] if ret == "void" else ["    return %s;" % zero]) + ["}", ""]
            rows.append((name, "implemented", target))
        elif name == "glGetStringi":
            lines += ["const GLubyte *glGetStringi(GLenum name, GLuint index)", "{",
                      "    const GLubyte *(*get)(GLenum) = (const GLubyte *(*)(GLenum))dlsym(RTLD_DEFAULT, \"glGetString\");",
                      "    if (name != 0x1F03 || !get) {", "        charon_es3_error();", "        return NULL;", "    }",
                      "    const char *text = (const char *)get(0x1F03);",
                      "    static char token[256];", "    while (text && *text) {",
                      "        while (*text == ' ')", "            text++;",
                      "        size_t length = strcspn(text, \" \");",
                      "        if (!length)", "            break;",
                      "        if (index-- == 0) {",
                      "            length = length < sizeof token - 1 ? length : sizeof token - 1;",
                      "            memcpy(token, text, length);", "            token[length] = 0;", "            return (const GLubyte *)token;", "        }",
                      "        text += length;", "    }", "    charon_es3_value_error();", "    return NULL;", "}", ""]
            rows.append((name, "implemented", "the i-th name of the extension string"))
        else:
            lines += ["%s %s(%s)" % (ret, name, params), "{", "    charon_es3_error();"] + ([] if ret == "void" else ["    return %s;" % zero]) + ["}", ""]
            rows.append((name, "inert", None))
    with open(os.path.join(package, "OpenGLES", output), "w") as out:
        out.write("\n".join(lines))
    return rows


def main(sdk):
    headers = os.path.join(sdk, "System/Library/Frameworks/OpenGLES.framework/Headers")
    older = prototypes(os.path.join(headers, "ES2/gl.h"))
    newer = prototypes(os.path.join(headers, "ES3/gl.h"))
    added = [name for name in newer if name not in older and name not in ALREADY]
    here = os.path.dirname(os.path.abspath(__file__))
    package = os.path.join(here, "..", "..", "..", "packages", "a", "apple-backports")
    rows = []
    for output, names in (("ES3Functions.m", [name for name in added if name not in QUERIES]),
                          ("ES3Queries.m", [name for name in added if name in QUERIES])):
        lines = ['#import <Foundation/Foundation.h>', '#import <OpenGLES/gltypes.h>', '#include <dlfcn.h>', '#include <string.h>', '',
                 '/* Generated by tests/backports/tools/gen-es3.py: what OpenGL ES 3.0 added to the ES 2.0 header. */', '',
                 'static void charon_es3_error(void)', '{',
                 '    void (*bind)(GLenum, GLuint) = (void (*)(GLenum, GLuint))dlsym(RTLD_DEFAULT, "glBindTexture");',
                 '    if (bind)', '        bind(0, 0);', '}', '']
        if "glGetStringi" in names:
            lines += ['static void charon_es3_value_error(void)', '{',
                      '    void (*generate)(GLsizei, GLuint *) = (void (*)(GLsizei, GLuint *))dlsym(RTLD_DEFAULT, "glGenTextures");',
                      '    if (generate)', '        generate(-1, NULL);', '}', '']
        rows += write_functions(package, output, lines, newer, names)
    rows.sort(key=lambda row: added.index(row[0]))
    facts = "facts/OpenGLES/ES3Functions.md"
    source = "the ES 3.0 header of the SDK against its ES 2.0 header for the names, and the shared caches of iOS 6.0 to 7.0.1 for the extensions the release has"
    entries = []
    for name, status, target in rows:
        entry = {"api": name + "()", "kind": "function", "introduced": "7.0", "status": status, "facts": facts, "source": source}
        if status == "inert":
            entry["reason"] = "the driver of the release is OpenGL ES 2.0 and has no such call"
            entry["effect"] = "the call does nothing, sets GL_INVALID_ENUM and answers zero"
        entries.append(entry)
    entries.append({"api": "kEAGLColorFormatSRGBA8", "kind": "constant", "introduced": "7.0", "status": "inert", "facts": facts,
                    "reason": "the drawable of the release is not sRGB",
                    "effect": "the name is there and asked for in a drawable's properties like any other, and the drawable is the format it would have been without it",
                    "source": "the SDK header for the name; the release's EAGL for the drawable"})
    os.makedirs(os.path.join(package, "registry", "OpenGLES"), exist_ok=True)
    with open(os.path.join(package, "registry", "OpenGLES", "base.json"), "w") as out:
        json.dump(entries, out, indent=2)
        out.write("\n")
    print(len(added), "functions,", len([r for r in rows if r[1] == "implemented"]), "answered through an extension")


if __name__ == "__main__":
    main(sys.argv[1])
