import Foundation
import ObjectiveC

typealias RawAllocate = @convention(c) (UnsafeRawPointer?, UnsafePointer<CChar>, Int) -> UnsafeRawPointer?
let rawAllocate = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_allocateClassPair"), to: RawAllocate.self)
nonisolated(unsafe) var truth: UnsafeRawPointer?

func allocate(_ name: String) -> AnyClass? {
  truth = rawAllocate(unsafeBitCast(W.self as AnyClass, to: UnsafeRawPointer.self), name, 0)
  return truth.map { unsafeBitCast($0, to: AnyClass.self) }
}

@objc(ProbeW)
final class W: NSObject {
  @objc static func makeCast() -> W.Type? {
    return allocate("ProbeCast") as? W.Type
  }

  @objc static func makeNoCast() -> AnyClass? {
    return allocate("ProbeNoCast")
  }

  @objc static func makeBitCast() -> W.Type? {
    return allocate("ProbeBitCast").map { unsafeBitCast($0, to: W.Type.self) }
  }

  @objc static func makeRegisteredCast() -> W.Type? {
    let pair = allocate("ProbeRegisteredCast")
    if let pair { objc_registerClassPair(pair) }
    return pair as? W.Type
  }

  @objc static func makeLikeExpo(module: W, appId: String?) -> W.Type? {
    let prefixedViewName = if let appId = appId {
      "ProbeLike_\(appId)"
    } else {
      "ProbeLike"
    }
    return prefixedViewName.withCString { viewNamePtr in
      let wrapperClass: AnyClass? = objc_allocateClassPair(W.self, viewNamePtr, 0)
      let wrappedModuleBlock: @convention(block) () -> W = { module }
      let wrappedModuleImp: IMP = imp_implementationWithBlock(wrappedModuleBlock)
      class_addMethod(wrapperClass, NSSelectorFromString("wrappedModule"), wrappedModuleImp, "@@:")
      return wrapperClass as? W.Type
    }
  }
}

typealias Maker = @convention(c) (AnyClass, Selector) -> UnsafeRawPointer?
typealias LikeExpo = @convention(c) (AnyClass, Selector, AnyObject, NSString?) -> UnsafeRawPointer?

func report(_ label: String, _ returned: UnsafeRawPointer?, _ expected: UnsafeRawPointer?) {
  let verdict = returned == expected ? "OK" : "WRONG"
  print("classpair: \(label) \(verdict) returned \(String(describing: returned)) allocated \(String(describing: expected))")
  fflush(stdout)
}

for name in ["makeCast", "makeNoCast", "makeBitCast", "makeRegisteredCast"] {
  truth = nil
  let selector = NSSelectorFromString(name)
  guard let method = class_getClassMethod(W.self, selector) else {
    print("classpair: \(name) ERROR no Objective-C method")
    fflush(stdout)
    continue
  }
  let make = unsafeBitCast(method_getImplementation(method), to: Maker.self)
  report(name, make(W.self, selector), truth)
}

let likeSelector = NSSelectorFromString("makeLikeExpoWithModule:appId:")
if let method = class_getClassMethod(W.self, likeSelector) {
  let make = unsafeBitCast(method_getImplementation(method), to: LikeExpo.self)
  let returned = make(W.self, likeSelector, W(), nil)
  let isWrapper = returned.map { $0.load(as: UInt32.self) == 0x305 } ?? false
  let name = returned.flatMap { isWrapper ? nil : String(cString: class_getName(unsafeBitCast($0, to: AnyClass.self))) }
  let verdict = name == "ProbeLike" ? "OK" : "WRONG"
  print("classpair: makeLikeExpo \(verdict) returned \(String(describing: returned)) wrapper \(isWrapper) name \(name ?? "none")")
  fflush(stdout)
} else {
  print("classpair: makeLikeExpo ERROR no Objective-C method")
  fflush(stdout)
}

print("classpair: done")
fflush(stdout)
exit(0)
