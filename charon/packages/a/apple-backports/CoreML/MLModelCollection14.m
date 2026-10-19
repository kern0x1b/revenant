/* The name Core ML posts when a model collection changes: MLModelCollectionDidChangeNotification, the constant of
 * MLModelCollection.h (iOS 14.0, sunset in 17.4).
 *
 * Its value is the string the host's Core ML gives under the symbol, read through dlsym in the host's own framework:
 * the string is the name of the symbol itself. tests/backports/host/coreml-collection14 reads it on the host and in
 * the port on every run and fails if they differ.
 *
 * The port carries no model collection (the class and its entries are owed, facts/CoreML/ModelCollection.md), so
 * nothing in the port posts this name. An application that observes it on the host is told the same name here. */
#import <Foundation/Foundation.h>

NSString *const MLModelCollectionDidChangeNotification = @"MLModelCollectionDidChangeNotification";
