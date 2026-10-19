// init-classes.inc - the class population this harness keeps honest, with the properties the port
// synthesizes for each. Generated; the two derivations are:
//
//   the class list, from the registry - every status `implemented` row that names `-[<class> init]`,
//   read from packages/a/apple-backports/registry/Intents/ios*.json by registry_classes() in
//   tools/intents/gen-init-classes.lua:
//
//   the properties, from the port's own objects - the `@synthesize NAME = _NAME;` lines inside
//   each class's @implementation in packages/a/apple-backports/Intents/IN*.m, CharonIntents100.m
//   and CharonIntents110.m, read by synthesised() in the same file:
//
//     xmake l tools/intents/gen-init-classes.lua -o tests/backports/host/intents-init/init-classes.inc
//
// The class list is read from the registry and not from the SDK headers, because the claim under
// test is the registry's: the header says which classes mark -init NS_UNAVAILABLE, the registry
// says which rows claim the port answers one, and this harness measures the second.
//
// The properties are read from the port and not from the runtime, because those are the ones the
// row claims stay nil. Asking the runtime instead yields NSObject's hash/description/debugDescription/
// superclass repeated four times over plus the framework's private accessors - measured, 48
// properties for INActivateCarSignalIntentResponse - which is neither the population the claim is
// about nor safe to call. A class that synthesizes nothing is listed with an empty set and its
// -init is measured on the IMP and the call alone.
//
// A class added to the registry and not here is invisible to the harness. run.sh prints the
// registry's own count of these rows beside this file's, and fails when the two disagree, which is
// what keeps this file honest: both this file and expected.txt are written from here, so comparing
// them with each other would only show that they agree.
//
// 112 classes, 7 of which synthesize no property: INGetRideStatusIntent, INIntentDonationMetadata, INListCarsIntent, INRelevanceProvider, INRelevantShortcutStore, INUserContext, INVoiceShortcutCenter

    { "INActivateCarSignalIntentResponse", { "code", "signals", NULL } },
    { "INAddMediaIntentResponse", { "code", NULL } },
    { "INAddTasksIntentResponse", { "addedTasks", "code", "modifiedTaskList", NULL } },
    { "INAirline", { "iataCode", "icaoCode", "name", NULL } },
    { "INAirport", { "iataCode", "icaoCode", "name", NULL } },
    { "INAirportGate", { "airport", "gate", "terminal", NULL } },
    { "INAnswerCallIntentResponse", { "callRecords", "code", NULL } },
    { "INAppendToNoteIntentResponse", { "code", "note", NULL } },
    { "INBalanceAmount", { "amount", "balanceType", "currencyCode", NULL } },
    { "INBillDetails", { "amountDue", "billPayee", "billType", "dueDate", "lateFee", "minimumDue", "paymentDate", "paymentStatus", NULL } },
    { "INBillPayee", { "accountNumber", "nickname", "organizationName", NULL } },
    { "INBoatReservation", { "boatTrip", "reservedSeat", NULL } },
    { "INBoatTrip", { "arrivalBoatTerminalLocation", "boatName", "boatNumber", "departureBoatTerminalLocation", "provider", "tripDuration", NULL } },
    { "INBusReservation", { "busTrip", "reservedSeat", NULL } },
    { "INBusTrip", { "arrivalBusStopLocation", "arrivalPlatform", "busName", "busNumber", "departureBusStopLocation", "departurePlatform", "provider", "tripDuration", NULL } },
    { "INCallGroup", { "groupId", "groupName", NULL } },
    { "INCallRecord", { "callCapability", "callDuration", "callRecordType", "dateCreated", "identifier", "isCallerIdBlocked", "numberOfCalls", "participants", "unseen", NULL } },
    { "INCallRecordFilter", { "callCapability", "callTypes", "participants", NULL } },
    { "INCancelRideIntent", { "rideIdentifier", NULL } },
    { "INCancelRideIntentResponse", { "cancellationFee", "cancellationFeeThreshold", "code", NULL } },
    { "INCancelWorkoutIntentResponse", { "code", NULL } },
    { "INCar", { "carIdentifier", "color", "displayName", "headUnit", "make", "model", "supportedChargingConnectors", "year", NULL } },
    { "INCarHeadUnit", { "bluetoothIdentifier", "iAP2Identifier", NULL } },
    { "INCreateNoteIntentResponse", { "code", "createdNote", NULL } },
    { "INCreateTaskListIntentResponse", { "code", "createdTaskList", NULL } },
    { "INCurrencyAmount", { "amount", "currencyCode", NULL } },
    { "INDateComponentsRange", { "endDateComponents", "recurrenceRule", "startDateComponents", NULL } },
    { "INDefaultCardTemplate", { "image", "subtitle", "title", NULL } },
    { "INDeleteTasksIntentResponse", { "code", "deletedTasks", NULL } },
    { "INEditMessageIntentResponse", { "code", NULL } },
    { "INEndWorkoutIntentResponse", { "code", NULL } },
    { "INFlight", { "airline", "arrivalAirportGate", "boardingTime", "departureAirportGate", "flightDuration", "flightNumber", NULL } },
    { "INFocusStatus", { "isFocused", NULL } },
    { "INGetCarLockStatusIntentResponse", { "code", "locked", NULL } },
    { "INGetCarPowerLevelStatusIntentResponse", { "activeConnector", "carIdentifier", "chargePercentRemaining", "charging", "chargingFormulaArguments", "code", "consumptionFormulaArguments", "currentBatteryCapacity", "dateOfLastStateUpdate", "distanceRemaining", "distanceRemainingElectric", "distanceRemainingFuel", "fuelPercentRemaining", "maximumBatteryCapacity", "maximumDistance", "maximumDistanceElectric", "maximumDistanceFuel", "minimumBatteryCapacity", "minutesToFull", NULL } },
    { "INGetReservationDetailsIntentResponse", { "code", "reservations", NULL } },
    { "INGetRideStatusIntent", { NULL } },
    { "INGetRideStatusIntentResponse", { "code", "rideStatus", NULL } },
    { "INGetVisualCodeIntentResponse", { "code", "visualCodeImage", NULL } },
    { "INHangUpCallIntentResponse", { "code", NULL } },
    { "INIntentDonationMetadata", { NULL } },
    { "INIntentResolutionResult", { NULL } },
    { "INInteraction", { "intent", "intentResponse", "intentHandlingStatus", "direction", "dateInterval", "identifier", "groupIdentifier", NULL } },
    { "INListCarsIntent", { NULL } },
    { "INListCarsIntentResponse", { "cars", "code", NULL } },
    { "INListRideOptionsIntentResponse", { "code", "expirationDate", "paymentMethods", "rideOptions", NULL } },
    { "INMediaDestination", { "mediaDestinationType", "playlistName", NULL } },
    { "INMediaItem", { "artist", "artwork", "identifier", "title", "type", NULL } },
    { "INMediaSearch", { "albumName", "artistName", "genreNames", "mediaIdentifier", "mediaName", "mediaType", "moodNames", "reference", "releaseDate", "sortOrder", NULL } },
    { "INMediaUserContext", { "numberOfLibraryItems", "subscriptionStatus", NULL } },
    { "INMessage", { "audioMessageFile", "content", "conversationIdentifier", "dateSent", "groupName", "identifier", "messageType", "recipients", "sender", "serviceName", NULL } },
    { "INObject", { "alternativeSpeakableMatches", "displayImage", "displayString", "identifier", "pronunciationHint", "spokenPhrase", "subtitleString", "vocabularyIdentifier", NULL } },
    { "INObjectCollection", { "allItems", "sections", "usesIndexedCollation", NULL } },
    { "INObjectSection", { "items", "title", NULL } },
    { "INPauseWorkoutIntentResponse", { "code", NULL } },
    { "INPayBillIntentResponse", { "billDetails", "code", "fromAccount", "transactionAmount", "transactionNote", "transactionScheduledDate", NULL } },
    { "INPaymentAccount", { "accountNumber", "accountType", "balance", "nickname", "organizationName", "secondaryBalance", NULL } },
    { "INPaymentAmount", { "amount", "amountType", NULL } },
    { "INPaymentMethod", { "type", "name", "identificationHint", "icon", NULL } },
    { "INPaymentRecord", { "currencyAmount", "feeAmount", "note", "payee", "payer", "paymentMethod", "status", NULL } },
    { "INPerson", { "contactIdentifier", "contactSuggestion", "customIdentifier", "displayName", "image", "nameComponents", "personHandle", "relationship", NULL } },
    { "INPersonHandle", { "label", "type", "value", NULL } },
    { "INPlayMediaIntentResponse", { "code", "nowPlayingInfo", NULL } },
    { "INPriceRange", { "currencyCode", "maximumPrice", "minimumPrice", NULL } },
    { "INRecurrenceRule", { "frequency", "interval", "weeklyRecurrenceDays", NULL } },
    { "INRelevanceProvider", { NULL } },
    { "INRelevantShortcutStore", { NULL } },
    { "INRentalCar", { "make", "model", "rentalCarDescription", "rentalCompanyName", "type", NULL } },
    { "INRequestPaymentIntentResponse", { "code", "paymentRecord", NULL } },
    { "INRequestRideIntentResponse", { "code", "rideStatus", NULL } },
    { "INReservation", { "URL", "actions", "bookingTime", "itemReference", "reservationHolderName", "reservationNumber", "reservationStatus", NULL } },
    { "INReservationAction", { "type", "userActivity", "validDuration", NULL } },
    { "INResumeWorkoutIntentResponse", { "code", NULL } },
    { "INRideCompletionStatus", { "completionUserActivity", "defaultTippingOptions", NULL } },
    { "INRideFareLineItem", { "currencyCode", "price", "title", NULL } },
    { "INRideOption", { "availablePartySizeOptions", "availablePartySizeOptionsSelectionPrompt", "disclaimerMessage", "estimatedPickupDate", "fareLineItems", "name", "priceRange", "specialPricing", "specialPricingBadgeImage", "userActivityForBookingInApplication", "usesMeteredFare", NULL } },
    { "INRidePartySizeOption", { "partySizeRange", "priceRange", "sizeDescription", NULL } },
    { "INSaveProfileInCarIntentResponse", { "code", NULL } },
    { "INSearchCallHistoryIntentResponse", { "callRecords", "code", NULL } },
    { "INSearchForAccountsIntentResponse", { "accounts", "code", NULL } },
    { "INSearchForBillsIntentResponse", { "bills", "code", NULL } },
    { "INSearchForMediaIntentResponse", { "code", "mediaItems", NULL } },
    { "INSearchForMessagesIntentResponse", { "code", "messages", NULL } },
    { "INSearchForNotebookItemsIntentResponse", { "code", "notes", "sortType", "taskLists", "tasks", NULL } },
    { "INSearchForPhotosIntentResponse", { "code", "searchResultsCount", NULL } },
    { "INSeat", { "seatNumber", "seatRow", "seatSection", "seatingType", NULL } },
    { "INSendMessageIntentDonationMetadata", { "mentionsCurrentUser", "notifyRecipientAnyway", "recipientCount", "replyToCurrentUser", NULL } },
    { "INSendMessageIntentResponse", { "code", "sentMessages", NULL } },
    { "INSendPaymentIntentResponse", { "code", "paymentRecord", NULL } },
    { "INSendRideFeedbackIntent", { "rating", "rideIdentifier", "tip", NULL } },
    { "INSendRideFeedbackIntentResponse", { "code", NULL } },
    { "INSetAudioSourceInCarIntentResponse", { "code", NULL } },
    { "INSetCarLockStatusIntentResponse", { "code", NULL } },
    { "INSetClimateSettingsInCarIntentResponse", { "code", NULL } },
    { "INSetDefrosterSettingsInCarIntentResponse", { "code", NULL } },
    { "INSetMessageAttributeIntentResponse", { "code", NULL } },
    { "INSetProfileInCarIntentResponse", { "code", NULL } },
    { "INSetRadioStationIntentResponse", { "code", NULL } },
    { "INSetSeatSettingsInCarIntentResponse", { "code", NULL } },
    { "INSetTaskAttributeIntentResponse", { "code", "modifiedTask", NULL } },
    { "INShareFocusStatusIntentResponse", { "code", NULL } },
    { "INShortcut", { "intent", "userActivity", NULL } },
    { "INSnoozeTasksIntentResponse", { "code", "snoozedTasks", NULL } },
    { "INSpeakableString", { "spokenPhrase", "pronunciationHint", "vocabularyIdentifier", "alternativeSpeakableMatches", NULL } },
    { "INStartAudioCallIntentResponse", { "code", NULL } },
    { "INStartCallIntentResponse", { "code", NULL } },
    { "INStartPhotoPlaybackIntentResponse", { "code", "searchResultsCount", NULL } },
    { "INStartVideoCallIntentResponse", { "code", NULL } },
    { "INStartWorkoutIntentResponse", { "code", NULL } },
    { "INTicketedEvent", { "category", "eventDuration", "location", "name", NULL } },
    { "INTrainTrip", { "arrivalPlatform", "arrivalStationLocation", "departurePlatform", "departureStationLocation", "provider", "trainName", "trainNumber", "tripDuration", NULL } },
    { "INTransferMoneyIntentResponse", { "code", "fromAccount", "toAccount", "transactionAmount", "transactionNote", "transactionScheduledDate", "transferFee", NULL } },
    { "INUnsendMessagesIntentResponse", { "code", NULL } },
    { "INUpdateMediaAffinityIntentResponse", { "code", NULL } },
    { "INUserContext", { NULL } },
    { "INVoiceShortcut", { "identifier", "invocationPhrase", "shortcut", NULL } },
    { "INVoiceShortcutCenter", { NULL } },
