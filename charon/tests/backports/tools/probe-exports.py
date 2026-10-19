#!/usr/bin/env python3
import argparse
import glob
import json
import os
import re
import subprocess
import sys

PROGRAM = "exportprobe"

SOURCE = r'''#import <Foundation/Foundation.h>
#include <dlfcn.h>

int main(void)
{
    NSArray *folders = @[@"/System/Library/Frameworks", @"/System/Library/PrivateFrameworks"];
    int opened = 0;
    for (NSString *folder in folders) {
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL]) {
            if (![name hasSuffix:@".framework"])
                continue;
            NSString *path = [NSString stringWithFormat:@"%@/%@/%@", folder, name, [name stringByDeletingPathExtension]];
            if (dlopen([path UTF8String], RTLD_LAZY))
                opened++;
        }
    }
    printf("opened %d\n", opened);
    const char *names[] = {@NAMES@ NULL};
    for (int i = 0; names[i]; i++)
        if (dlsym(RTLD_DEFAULT, names[i]))
            printf("exported %s\n", names[i]);
    printf("done\n");
    return 0;
}
'''

RECIPE = '''set_project("exportprobe")
set_version("0.1.0")
add_repositories("charon @CHARON@")
add_addons("charon latest")
set_config("apple_minimum", "@RELEASE@")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
target("exportprobe")
    add_rules("@addon/charon/daemon")
    add_files("probe.m")
    add_frameworks("Foundation")
    set_values("charon.control", "packaging/control")
'''

CONTROL = '''Package: org.charon.exportprobe
Name: Charon export probe
Architecture: iphoneos-arm
Description: asks the release which names it exports
Maintainer: charon
Author: charon
Section: Development
'''


def registry_names(root):
    """Every constant and function the registry of every framework lists as absent, and the file each is
    listed in. A name in two files is refused: the two rows would answer for one name, and only the last
    would decide whether the release exports it."""
    names, told = {}, {}
    files = glob.glob(os.path.join(root, "registry", "*.json")) + glob.glob(os.path.join(root, "registry", "*", "*.json"))
    for file in sorted(files):
        held = json.load(open(file))
        for entry in held["entries"] if isinstance(held, dict) else held:
            name = re.sub(r"\(\)$", "", entry["api"])
            if name in told:
                sys.exit("%s is named by both %s and %s" % (entry["api"], told[name], os.path.relpath(file, root)))
            told[name] = os.path.relpath(file, root)
            if entry.get("status") == "absent" and entry.get("kind") in ("constant", "function"):
                names.setdefault(name, []).append(os.path.relpath(file, root))
    return names


def run(command, cwd, environment=None):
    return subprocess.run(command, cwd=cwd, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    checkout = os.path.abspath(os.path.join(here, "..", "..", ".."))
    parser = argparse.ArgumentParser(description="Asks a release which of some C names it exports itself, by loading every framework of the release in the emulator and calling dlsym for each name. A constant or a function the registry lists as absent that the release exports is the release's own, and absent tells an application it is not there.")
    parser.add_argument("--names", help="a file with one name a line, a function without its parentheses")
    parser.add_argument("--registry", action="store_true", help="probe every constant and function the registry of the package lists as absent, and exit 1 when the release exports one")
    parser.add_argument("--release", default="6.0", help="the release to emulate (default 6.0)")
    parser.add_argument("--charon", default=checkout, help="the tree that holds the package repository (default: this one)")
    parser.add_argument("--workdir", required=True, help="a folder for the probe project; it is emptied first")
    options = parser.parse_args()
    root = os.path.join(options.charon, "packages", "a", "apple-backports")
    if options.registry:
        listed = registry_names(root)
    elif options.names:
        listed = {line.strip(): [] for line in open(options.names) if line.strip()}
    else:
        parser.error("name the names with --names or --registry")
    if not listed:
        sys.exit("there are no names to ask about")
    workdir = os.path.abspath(options.workdir)
    subprocess.run(["rm", "-rf", workdir])
    os.makedirs(os.path.join(workdir, "packaging"))
    literal = "".join('"%s", ' % name for name in sorted(listed))
    open(os.path.join(workdir, "probe.m"), "w").write(SOURCE.replace("@NAMES@", literal))
    open(os.path.join(workdir, "xmake.lua"), "w").write(RECIPE.replace("@CHARON@", options.charon).replace("@RELEASE@", options.release))
    open(os.path.join(workdir, "packaging", "control"), "w").write(CONTROL)
    for command in (["xmake", "f", "-y", "-c"], ["xmake", "-y"], ["xmake", "emulate", "install"]):
        result = run(command, workdir)
        if result.returncode != 0:
            sys.exit("%s failed:\n%s" % (" ".join(command), result.stdout))
    result = run(["xmake", "emulate", "run", "/usr/libexec/" + PROGRAM], workdir)
    exported = sorted(line.split()[1] for line in result.stdout.splitlines() if line.startswith("exported "))
    if "done" not in result.stdout:
        sys.exit("the probe did not finish:\n%s" % result.stdout)
    print("%d of %d names are exported by iOS %s" % (len(exported), len(listed), options.release))
    for name in exported:
        print("exported %s %s" % (name, " ".join(listed[name])))
    if options.registry and exported:
        sys.exit(1)


if __name__ == "__main__":
    main()
