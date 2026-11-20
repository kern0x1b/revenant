import Foundation
import CoreFoundation

func check(_ condition: Bool, _ label: String) {
    if !condition {
        fatalError(label)
    }
}

let dictionary: NSMutableDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, nil, nil) as! NSMutableDictionary
check(dictionary as? NSMutableDictionary != nil, "as? NSMutableDictionary")
check((dictionary as! NSMutableDictionary) === dictionary, "as! NSMutableDictionary")

let array: NSMutableArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, nil) as! NSMutableArray
check(array as? NSMutableArray != nil, "as? NSMutableArray")
check((array as! NSMutableArray) === array, "as! NSMutableArray")

let string: NSMutableString = CFStringCreateMutable(kCFAllocatorDefault, 0) as! NSMutableString
check(string as? NSMutableString != nil, "as? NSMutableString")
check((string as! NSMutableString) === string, "as! NSMutableString")

let data: NSMutableData = CFDataCreateMutable(kCFAllocatorDefault, 0) as! NSMutableData
check(data as? NSMutableData != nil, "as? NSMutableData")
check((data as! NSMutableData) === data, "as! NSMutableData")

let set: NSMutableSet = CFSetCreateMutable(kCFAllocatorDefault, 0, nil) as! NSMutableSet
check(set as? NSMutableSet != nil, "as? NSMutableSet")
check((set as! NSMutableSet) === set, "as! NSMutableSet")

check(NSNull() as AnyObject === kCFNull, "NSNull singleton is kCFNull")
