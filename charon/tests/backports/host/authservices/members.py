"""The public members of a class, from clang's AST over its own header.

The first version of the shape check took the member list out of the headers with regular expressions,
and that is where a selector nobody declared came from: a regex cannot tell a method declaration from
a property's accessors the way a parser can, and it cannot tell an instance method from a class one.
So the list is taken from clang instead, which is the same front end the port's own sources are
compiled by -- the answer is the header as the compiler reads it, not as a pattern reads it.

Three things come out of the AST that a text scan cannot give:

  * **the full selector**, so `initWithURL:callbackURLScheme:completionHandler:` is one member and not
    three, and a one-part `initWithURL:` is not a member at all;
  * **instance or class**, so `+new` and `-init` are different members of the same class;
  * **`NS_UNAVAILABLE`**, which is an attribute on the declaration. A method the release marks
    unavailable is not asked about as something the port must have: it is asked about as something that
    must NOT be callable, which is a different question and the one the header is actually making.

Usage: members.py <headers-dir> <class> [<class> ...]
Prints: <class>\\t<selector>\\tinstance|class\\tavailable|must-be-unavailable
"""
import json
import os
import subprocess
import sys


def ast_of(header):
    """The AST of one header, as clang sees it with the headers it needs in scope.

    AuthenticationServices' headers need Foundation and CoreFoundation and the platform module map, or
    the parse stops at the first missing type and the class is never reached -- which would look like a
    class with no members rather than a class that was never parsed.
    """
    command = [
        "clang", "-x", "objective-c", "-fsyntax-only", "-Xclang", "-ast-dump=json",
        "-I" + os.path.dirname(os.path.abspath(header)),
    ]
    for extra in [f for f in os.environ.get("MEMBERS_CFLAGS", "").split() if f]:
        command.append(extra)
    command.append(header)
    out = subprocess.run(command, capture_output=True, text=True)
    if out.returncode != 0 and not out.stdout:
        raise SystemExit("clang could not read %s: %s" % (header, out.stderr.strip()[:400]))
    return json.loads(out.stdout)


def children(node, kind):
    """The direct children of one kind.

    The walk is complete: a cap on how many children a node is looked at truncates the translation
    unit before the class is reached, which looks exactly like a class with no members -- a check that
    cannot tell "the header has no methods" from "the walk stopped early" is a check that passes.
    """
    return [child for child in node.get("inner", []) if child.get("kind") == kind]


def has_unavailable(decl):
    """Whether the release marks this method unavailable.

    `NS_UNAVAILABLE` is an UnavailableAttr on the declaration itself, which is the shape the AST gives
    -- not a word in the declaration's text, and not the availability attributes the interface carries
    for the class as a whole.
    """
    return bool(children(decl, "UnavailableAttr"))


def selector_of(decl):
    """The full selector of an ObjCMethodDecl, every part with its colon.

    A keyword method carries its parts in `selector` -- initWithURL, callbackURLScheme,
    completionHandler -- and the selector is those parts joined, the last given its colon back. A method
    that takes no argument has no `selector` at all and its whole selector is `name`. This is the one
    thing a text scan gets wrong most easily: `initWithURL:callbackURLScheme:completionHandler:` is one
    member, and `initWithURL:` on its own is not a member of anything.
    """
    parts = decl.get("selector")
    if parts:
        text = ":".join(parts)
        return text + ":"
    return decl.get("name")


def members_of(node, className):
    for decl in children(node, "ObjCInterfaceDecl"):
        if decl.get("name") != className:
            continue
        for method in children(decl, "ObjCMethodDecl"):
            selector = selector_of(method)
            if not selector:
                continue
            # `instance` is a boolean on the declaration, not a bit in a methodFlags word.
            kind = "instance" if method.get("instance") else "class"
            state = "must-be-unavailable" if has_unavailable(method) else "available"
            yield selector, kind, state


def main(argv):
    if len(argv) < 3:
        raise SystemExit("usage: members.py <headers-dir> <class> [...]")
    headers, classes = argv[1], argv[2:]
    # A class the PORT defines has its header in the port, not in the SDK, and looking only in the SDK is
    # the same mistake the writing-selectors scan made: reading the wrong directory rather than reading
    # the wrong thing. So a class with no SDK header is looked for in the port's own headers, and the
    # row says which directory answered, because "this class is implemented" and "nobody read its
    # declaration" are different claims and only one of them is a defect.
    port_headers = os.environ.get("PORT_HEADERS", "")
    for className in classes:
        path = os.path.join(headers, className + ".h")
        if not os.path.isfile(path) and port_headers:
            candidate = os.path.join(port_headers, className + ".h")
            if os.path.isfile(candidate):
                sys.stderr.write("%s: the SDK has no header, so the port's own was read: %s\n"
                                 % (className, candidate))
                path = candidate
        if not os.path.isfile(path):
            sys.stderr.write("no header for %s: %s, and none in %s\n" % (className, path, port_headers or "(no port headers)"))
            sys.exit(1)
        node = ast_of(path)
        found = list(members_of(node, className))
        if not found:
            sys.stderr.write("%s: the header declares no method the AST can see\n" % className)
            sys.exit(1)
        for selector, kind, state in found:
            print("%s\t%s\t%s\t%s" % (className, selector, kind, state))


if __name__ == "__main__":
    main(sys.argv)
