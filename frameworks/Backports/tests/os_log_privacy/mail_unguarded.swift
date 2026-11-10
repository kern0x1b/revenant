import os

@available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, *)
func unguardedMail(_ logger: Logger, _ text: String) {
    logger.info("mail \(text, privacy: .private(mask: ._mailAddress))")
}
