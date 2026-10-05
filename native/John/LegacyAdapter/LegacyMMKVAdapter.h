#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const JohnLegacyMMKVErrorDomain;

/// Reads known string values and all key names from the default MMKV instance.
/// The adapter opens the store read-only and does not modify the input files.
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable JohnReadLegacyMMKV(
    NSString *rootPath,
    NSArray<NSString *> *knownKeys,
    NSError **error
);

NS_ASSUME_NONNULL_END
