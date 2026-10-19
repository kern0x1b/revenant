#!/usr/bin/env python3
"""apply-anchor <anchor-file> <replacement-file> <target> -- the one edit a mutant makes.

The anchor and the replacement are READ FROM FILES rather than passed as values, and that is the whole
point of them being files: the replace anchor is two lines, and a two-line value passed through a
positional parameter and an environment variable is how it lost its newline. The mutation is applied to
the ONE named target file, because the first helper ran its pattern over every .m in the copy and a
change meant for one method could land in another -- a bigger mutation than the one asked for, and a
crash is what a too-big mutation looks like.
"""
import sys


def show(anchor, text):
    """The two reprs, so that a reader can see the bytes rather than be told about them.

    The comparison below reported "the anchor is not in <file>" for a file it demonstrably WAS in --
    checked separately and found to contain it -- and the two readers of the same two files are the
    only thing that can differ. A CRLF the shell did not show, a tab where the eye sees spaces, a
    trailing space, an rstrip on one side: every one of those is invisible in a message and obvious in
    a repr. So the reprs are printed, always, and the verdict is under them.
    """
    first = anchor.splitlines()[0] if anchor.splitlines() else ""
    at = text.find(first)
    print("  anchor repr : %r" % (anchor[:120],))
    print("  text   repr : %r" % (text[at:at + 200] if at >= 0 else "(the first line is not present)",))
    print("  found       : %s   (anchor %d bytes, %d lines)"
          % (anchor in text, len(anchor), len(anchor.splitlines())))


def main(argv):
    if len(argv) != 4:
        sys.stderr.write("usage: apply-anchor <anchor-file> <replacement-file> <target>\n")
        return 2
    anchor = open(argv[1], encoding="utf-8").read().rstrip("\n")
    replacement = open(argv[2], encoding="utf-8").read().rstrip("\n")
    path = argv[3]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    show(anchor, text)
    if anchor not in text:
        # What the caller actually handed over, because the run that reported "the anchor is not in"
        # for a file that demonstrably WAS in it, and the only thing that can differ between the two is
        # what arrived here.
        sys.stderr.write("  argv   : %r\n" % (argv,))
        sys.stderr.write("  cwd    : %s\n" % os.getcwd())
        for index, given in enumerate(argv[:2]):
            sys.stderr.write("  arg%d %s exists=%s\n"
                             % (index + 1, given, os.path.isfile(given)))
        sys.stderr.write("the anchor is not in %s\n" % path)
        return 1
    with open(path, "w", encoding="utf-8") as f:
        f.write(text.replace(anchor, replacement, 1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
