import Foundation
import IOSurface

final class Surface {
    let ioSurface: IOSurface
    init(_ ioSurface: IOSurface) {
        self.ioSurface = ioSurface
    }
}
