// A program that imports SwiftUI and takes from it what an app takes: a view, a layout, a text, a modifier, an environment
// value, a binding. If the module is not what a port expects, this does not compile; if its library does not carry the
// module's object, this does not link. It says what it took, so a run can be read.
import SwiftUI

struct Row: Identifiable {
    let id: Int
    let title: String
}

struct Consumer: View {
    @State private var rows = [Row(id: 1, title: "one"), Row(id: 2, title: "two")]
    @State private var width: CGFloat = 20
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SwiftUI from a package")
                .font(.body)
                .foregroundColor(scheme == .dark ? .white : .black)
            ForEach(rows) { row in
                HStack {
                    Text(row.title)
                    Spacer()
                    Text("\\(row.id)")
                }
                .frame(width: width, height: 20)
            }
            Button("wider") { width += 10 }
                .buttonStyle(.bordered)
        }
        .padding(8)
    }
}

// The view's own type is named here, so the link keeps the module's object whatever the compiler inlines.
let made: AnyView = AnyView(Consumer())
print("consumer took \(type(of: made))")
LUA
ls -la; echo "--- write the run script"; cat > run.sh <<'SH'
#!/bin/sh
# tests/swiftui/consumer: the package as a port takes it. A program that imports SwiftUI, is built against the module the
# package installs and links its library; what the build leaves is read, so a package that installed a module without its
# library, or a library without the module's object, is a failure here and not a surprise in somebody else's port.
#
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/swiftui/consumer/run.sh
#
# One heavy job: it installs charon@swiftui into the shared store (the recipe's own digest is its buildhash, so a changed
# recipe is a new package and needs no force) and builds one program. SWIFTUI_ROOT names the checkout when this is not run
# from one, SWIFTUI_MINIMUM the release the port builds for (6.1.3: the release an armv7 device of the fleet runs).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
export SWIFTUI_ROOT=${SWIFTUI_ROOT:-$(cd "$here/../../.." && pwd)}
build=${SWIFTUI_BUILD:-${TMPDIR:-/tmp}/charon-swiftui-consumer}
rm -rf "$build"
mkdir -p "$build"
cp -R "$here" "$build/project"
cd "$build/project"
xmake f -y -c >/dev/null
xmake -y >"$build/build.log" 2>&1 || { tail -30 "$build/build.log"; exit 1; }
binary=$(find . -name consumer -type f -perm -u+x | head -1)
[ -n "$binary" ] || { echo "consumer: the build produced no binary"; tail -30 "$build/build.log"; exit 1; }
# The module, its textual interface and the library are what the package promises; each is named by what it is.
store=$(xmake require --info --requires "charon@swiftui" 2>/dev/null | head -1)
installdir=$(xmake show -l packages.swiftui 2>/dev/null | head -1)
[ -d "$installdir/lib/swift/iphoneos/SwiftUI.swiftmodule" ] || { echo "consumer: no module in the install"; exit 1; }
[ -f "$installdir/lib/swift/iphoneos/SwiftUI.swiftmodule/SwiftUI.swiftinterface" ] || { echo "consumer: no interface in the install"; exit 1; }
[ -f "$installdir/lib/libEidolonSwiftUI.a" ] || { echo "consumer: no library in the install"; exit 1; }
# The module's own symbol is in the binary: a linked library that carries nothing of the module is a library of no use.
if ! nm -u "$binary" 2>/dev/null | grep -qE "Eidolon" && ! nm -gU "$binary" 2>/dev/null | grep -qE "9SwiftUI"; then
    echo "consumer: the binary carries nothing of the SwiftUI module"; exit 1
fi
echo "consumer: built against the module, linked the library: $binary"
SH
chmod +x run.sh; echo ok