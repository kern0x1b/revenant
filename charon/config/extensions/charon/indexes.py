"""Check that a recipe index gives consumers the recipe its folder holds.

    python indexes.py [--canonical] INDEX...

Run it with the interpreter Conan runs under, because it asks Conan's own
trim_conandata what the index exports. A local recipe index trims each
conandata.yml to the version being exported, and a top-level table with no key
for that version is dropped. A table keyed by the versions the recipe serves has
nothing for a version it leaves out; a table keyed by anything else is lost for
every version, so a recipe that reads it fails only for whoever resolves it
through the index. With --canonical it also names every
conandata.yml whose text the trim rewrites: such a recipe gets one revision from
conan create in its folder and another from the index.
"""
import sys
import tempfile
from pathlib import Path

import yaml
from conan.tools.files import trim_conandata


class Exported:
    def __init__(self, folder, version):
        self.export_folder = str(folder)
        self.version = version
        self.conan_data = None


def findings(index):
    dropped, rewritten = [], []
    for config in sorted(Path(index).glob("recipes/*/config.yml")):
        versions = (yaml.safe_load(config.read_text()) or {}).get("versions") or {}
        for version, described in versions.items():
            path = config.parent / str((described or {}).get("folder", "")) / "conandata.yml"
            if not path.is_file():
                continue
            text = path.read_text()
            original = yaml.safe_load(text) or {}
            with tempfile.TemporaryDirectory() as folder:
                (Path(folder) / "conandata.yml").write_text(text)
                trim_conandata(Exported(folder, str(version)))
                trimmed = (Path(folder) / "conandata.yml").read_text()
            kept = yaml.safe_load(trimmed) or {}
            served = {str(served_version) for served_version in versions}
            lost = sorted(name for name in set(original) - set(kept)
                          if not (isinstance(original[name], dict) and served & {str(key) for key in original[name]}))
            if lost:
                dropped.append("{} {}: {} has no entry for {}, so the index drops it".format(
                    config.parent.name, version, ", ".join(lost), version))
            if len(versions) == 1 and trimmed != text:
                rewritten.append(str(path.relative_to(index)))
    return dropped, rewritten


def main(arguments):
    canonical = "--canonical" in arguments
    refused = False
    for index in [argument for argument in arguments if argument != "--canonical"]:
        dropped, rewritten = findings(index)
        for line in dropped:
            print("refused  {}".format(line))
            refused = True
        if canonical and rewritten:
            print("rewritten  {} in {}: the index exports different text, so conan create in the folder gives "
                  "another revision than consumers resolve".format(", ".join(rewritten), index))
    return 1 if refused else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
