/* config.h of xz 5.8.4 for the Compression backport: the subset of liblzma that the LZMA codec needs, derived from the
 * upstream's non-autotools configuration (dos/config.h). Enabled: the CRC32, CRC64 and SHA-256 checks, the LZMA1 and
 * LZMA2 coders and their match finders. Not enabled: the branch-call-jump filters, delta, lzip, threads, and the
 * x86 CRC assembly, so their sources are not built. SIZEOF_SIZE_T comes from the compiler, so the one file serves both the
 * armv7 port and the 64-bit host build of the differential. */
#define HAVE_CHECK_CRC32 1
#define HAVE_CHECK_CRC64 1
#define HAVE_CHECK_SHA256 1
#define HAVE_DECODERS 1
#define HAVE_DECODER_LZMA1 1
#define HAVE_DECODER_LZMA2 1
#define HAVE_ENCODERS 1
#define HAVE_ENCODER_LZMA1 1
#define HAVE_ENCODER_LZMA2 1
#define HAVE_INTTYPES_H 1
#define HAVE_MF_BT2 1
#define HAVE_MF_BT3 1
#define HAVE_MF_BT4 1
#define HAVE_MF_HC3 1
#define HAVE_MF_HC4 1
#define HAVE_STDBOOL_H 1
#define HAVE_STDINT_H 1
#define HAVE_VISIBILITY 0
#define HAVE__BOOL 1
#define HAVE___BUILTIN_ASSUME_ALIGNED 1
#define HAVE___BUILTIN_BSWAPXX 1
#define ASSUME_RAM 32
#define NDEBUG 1
#define PACKAGE_NAME "XZ Utils"
#define PACKAGE_BUGREPORT "xz@tukaani.org"
#define PACKAGE_URL "https://tukaani.org/xz/"
#define SIZEOF_SIZE_T __SIZEOF_SIZE_T__
#define TUKLIB_FAST_UNALIGNED_ACCESS 1
