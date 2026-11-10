import os

@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, *)
func privacyShapes(_ logger: Logger, _ text: String, _ count: Int) {
    logger.info("public \(text, privacy: .public)")
    logger.info("private \(text, privacy: .private)")
    logger.info("sensitive \(count, privacy: .sensitive)")
    logger.info("auto \(count, privacy: .auto)")
    logger.info("hashed \(text, privacy: .private(mask: .hash))")
    logger.info("auto hashed \(count, privacy: .auto(mask: .hash))")
    logger.info("sensitive hashed \(text, privacy: .sensitive(mask: .hash))")
    logger.info("default \(text)")
}

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
func mailShapes(_ logger: Logger, _ text: String) {
    logger.info("mail \(text, privacy: .private(mask: ._mailAddress))")
    logger.info("auto mail \(text, privacy: .auto(mask: ._mailName))")
    logger.info("sensitive mail \(text, privacy: .sensitive(mask: ._mailSubject))")
}
