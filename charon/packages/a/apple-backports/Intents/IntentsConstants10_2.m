#import <Intents/Intents.h>

// 38 constants, the 10.2 names first exported in that release, and nothing else: a name
// this file does not define is a name the corpus's gate asks for and the link cannot find, so the
// list below is the whole of this file's claim and the registry names each one of them.
//
// Every value was read out of the host's own Intents at runtime - dlsym over
// /System/Library/Frameworks/Intents.framework, the NSString *const dereferenced once - and the
// differential in tests/backports/host/intents/constants reads the same table out of two builds:
// Apple's framework on its own, and this file beside it in one binary with the names renamed.
//
// The object is split by the release each name first appears in, not by a version string:
// backports.lua's band() raises on an object mixing a name a band already exports with one it
// does not, and a single-band 6.1.3 gate cannot see it.  AVFoundation's metadata key-space
// objects are split the same way.
//
// The ledger's reason for every one of these, which is what this slice answers:
// "declared extern in the lifted headers and there is no such symbol in the built libraries or
// the 6.1.3 cache -- the port has to export it".


NSString *const INPersonHandleLabelHome = @"com.apple.intents.PersonHandleLabel.Home";
NSString *const INPersonHandleLabelHomeFax = @"com.apple.intents.PersonHandleLabel.Home_Fax";
NSString *const INPersonHandleLabelMain = @"com.apple.intents.PersonHandleLabel.Main";
NSString *const INPersonHandleLabelMobile = @"com.apple.intents.PersonHandleLabel.Mobile";
NSString *const INPersonHandleLabelOther = @"com.apple.intents.PersonHandleLabel.Other";
NSString *const INPersonHandleLabelPager = @"com.apple.intents.PersonHandleLabel.Pager";
NSString *const INPersonHandleLabelWork = @"com.apple.intents.PersonHandleLabel.Work";
NSString *const INPersonHandleLabelWorkFax = @"com.apple.intents.PersonHandleLabel.Work_Fax";
NSString *const INPersonHandleLabeliPhone = @"com.apple.intents.PersonHandleLabel.iPhone";
NSString *const INPersonRelationshipAssistant = @"com.apple.intents.PersonRelationship.Assistant";
NSString *const INPersonRelationshipBrother = @"com.apple.intents.PersonRelationship.Brother";
NSString *const INPersonRelationshipChild = @"com.apple.intents.PersonRelationship.Child";
NSString *const INPersonRelationshipFather = @"com.apple.intents.PersonRelationship.Father";
NSString *const INPersonRelationshipFriend = @"com.apple.intents.PersonRelationship.Friend";
NSString *const INPersonRelationshipManager = @"com.apple.intents.PersonRelationship.Manager";
NSString *const INPersonRelationshipMother = @"com.apple.intents.PersonRelationship.Mother";
NSString *const INPersonRelationshipParent = @"com.apple.intents.PersonRelationship.Parent";
NSString *const INPersonRelationshipPartner = @"com.apple.intents.PersonRelationship.Partner";
NSString *const INPersonRelationshipSister = @"com.apple.intents.PersonRelationship.Sister";
NSString *const INPersonRelationshipSpouse = @"com.apple.intents.PersonRelationship.Spouse";
NSString *const INWorkoutNameIdentifierCrosstraining = @"com.apple.intents.WorkoutNameIdentifier.Crosstraining";
NSString *const INWorkoutNameIdentifierCycle = @"com.apple.intents.WorkoutNameIdentifier.Cycle";
NSString *const INWorkoutNameIdentifierDance = @"com.apple.intents.WorkoutNameIdentifier.Dance";
NSString *const INWorkoutNameIdentifierElliptical = @"com.apple.intents.WorkoutNameIdentifier.Elliptical";
NSString *const INWorkoutNameIdentifierExercise = @"com.apple.intents.WorkoutNameIdentifier.Exercise";
NSString *const INWorkoutNameIdentifierIndoorcycle = @"com.apple.intents.WorkoutNameIdentifier.Indoorcycle";
NSString *const INWorkoutNameIdentifierIndoorrun = @"com.apple.intents.WorkoutNameIdentifier.Indoorrun";
NSString *const INWorkoutNameIdentifierIndoorwalk = @"com.apple.intents.WorkoutNameIdentifier.Indoorwalk";
NSString *const INWorkoutNameIdentifierMove = @"com.apple.intents.WorkoutNameIdentifier.Move";
NSString *const INWorkoutNameIdentifierOther = @"com.apple.intents.WorkoutNameIdentifier.Other";
NSString *const INWorkoutNameIdentifierRower = @"com.apple.intents.WorkoutNameIdentifier.Rower";
NSString *const INWorkoutNameIdentifierRun = @"com.apple.intents.WorkoutNameIdentifier.Run";
NSString *const INWorkoutNameIdentifierSit = @"com.apple.intents.WorkoutNameIdentifier.Sit";
NSString *const INWorkoutNameIdentifierStairs = @"com.apple.intents.WorkoutNameIdentifier.Stairs";
NSString *const INWorkoutNameIdentifierStand = @"com.apple.intents.WorkoutNameIdentifier.Stand";
NSString *const INWorkoutNameIdentifierSteps = @"com.apple.intents.WorkoutNameIdentifier.Steps";
NSString *const INWorkoutNameIdentifierWalk = @"com.apple.intents.WorkoutNameIdentifier.Walk";
NSString *const INWorkoutNameIdentifierYoga = @"com.apple.intents.WorkoutNameIdentifier.Yoga";
