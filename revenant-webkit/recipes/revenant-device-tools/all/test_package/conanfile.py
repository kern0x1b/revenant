from io import StringIO
import glob
import os
import re

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.layout import basic_layout


class TestPackage(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    test_type = "explicit"

    def requirements(self):
        self.requires(self.tested_reference_str)

    def layout(self):
        basic_layout(self)

    def _output(self, command):
        output = StringIO()
        self.run(command, stdout=output, stderr=output)
        return output.getvalue()

    def test(self):
        tools = self.dependencies["revenant-device-tools"]
        bindir = tools.cpp_info.bindirs[0]
        resdir = tools.cpp_info.resdirs[0]

        binaries = sorted(entry for entry in os.listdir(bindir) if os.path.isfile(os.path.join(bindir, entry)))
        if not binaries:
            raise ConanException(f"{bindir} holds no tools")
        for tool in binaries:
            binary = os.path.join(bindir, tool)
            archs = self._output(f'lipo -archs "{binary}"').split()
            if archs != [str(self.settings.arch)]:
                raise ConanException(f"{tool} is {archs}, not a thin {self.settings.arch} Mach-O")
            signature = self._output(f'codesign -dv "{binary}"')
            if "CodeDirectory" not in signature:
                raise ConanException(f"{tool} carries no code signature: {signature}")

        for document in sorted(glob.glob(os.path.join(resdir, "entitlements", "*.xml"))):
            tool = os.path.splitext(os.path.basename(document))[0]
            if tool not in binaries:
                raise ConanException(f"{document} entitles {tool}, which the package does not hold")
            with open(document) as handle:
                wanted = re.findall(r"<key>([^<]+)</key>", handle.read())
            carried = self._output(f'codesign -d --entitlements - "{os.path.join(bindir, tool)}"')
            for key in wanted:
                if key not in carried:
                    raise ConanException(f"{tool} is signed without {key}")

        launchd = glob.glob(os.path.join(resdir, "LaunchDaemons", "*.plist"))
        if not launchd:
            raise ConanException(f"{resdir}/LaunchDaemons holds no launch daemon")
