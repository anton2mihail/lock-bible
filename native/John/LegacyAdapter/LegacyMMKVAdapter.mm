#import "LegacyMMKVAdapter.h"

#include "MMKV.h"
#include "MMKVMetaInfo.hpp"

#include <cstdint>
#include <exception>
#include <mutex>
#include <string>
#include <sys/stat.h>
#include <vector>

NSErrorDomain const JohnLegacyMMKVErrorDomain = @"JohnLegacyMMKVErrorDomain";
static std::mutex JohnLegacyMMKVReadLock;

static NSString *JohnString(const std::string &value) {
    return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding];
}

NSDictionary<NSString *, id> *JohnReadLegacyMMKV(NSString *rootPath, NSArray<NSString *> *knownKeys, NSError **error) {
        @autoreleasepool {
        try {
            std::lock_guard<std::mutex> readLock(JohnLegacyMMKVReadLock);
            if (rootPath.length == 0) {
                if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:1
                    userInfo:@{NSLocalizedDescriptionKey: @"The MMKV root path is empty."}];
                return nil;
            }

            const std::string root(rootPath.fileSystemRepresentation);
            MMKVPath_t rootDirectory = root;
            const std::string dataPath = root + "/mmkv.default";
            const std::string crcPath = dataPath + ".crc";
            struct stat dataInfo {};
            struct stat crcInfo {};
            if (stat(dataPath.c_str(), &dataInfo) != 0 || stat(crcPath.c_str(), &crcInfo) != 0 ||
                !S_ISREG(dataInfo.st_mode) || !S_ISREG(crcInfo.st_mode)) {
                if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:5
                    userInfo:@{NSLocalizedDescriptionKey: @"The default MMKV data or CRC file is unavailable."}];
                return nil;
            }
            if (dataInfo.st_size < static_cast<off_t>(sizeof(uint32_t)) ||
                crcInfo.st_size < static_cast<off_t>(sizeof(mmkv::MMKVMetaInfo))) {
                if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:6
                    userInfo:@{NSLocalizedDescriptionKey: @"The default MMKV data or CRC file is truncated."}];
                return nil;
            }
            if (!MMKV::isFileValid("mmkv.default", &rootDirectory)) {
                if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:7
                    userInfo:@{NSLocalizedDescriptionKey: @"The default MMKV checksum is invalid."}];
                return nil;
            }
            MMKV::initializeMMKV(rootDirectory, MMKVLogNone);
            MMKV *store = MMKV::mmkvWithID("mmkv.default",
                static_cast<MMKVMode>(MMKV_SINGLE_PROCESS | MMKV_READ_ONLY), nullptr, &rootDirectory);
            if (!store || !store->isReadOnly()) {
                if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:2
                    userInfo:@{NSLocalizedDescriptionKey: @"The default MMKV store could not open in read-only mode."}];
                if (store) store->close();
                return nil;
            }
            struct StoreCloser {
                MMKV *store;
                ~StoreCloser() { if (store) store->close(); }
            } closer{store};

            NSMutableArray<NSString *> *keys = [NSMutableArray array];
            for (const auto &key : store->allKeys(false)) {
                NSString *name = JohnString(key);
                if (name) [keys addObject:name];
            }
            NSSet<NSString *> *known = [NSSet setWithArray:knownKeys];
            NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];
            for (NSString *key in keys) {
                if (![known containsObject:key] && ![key hasPrefix:@"vesper.sunday."]) continue;
                std::string value;
                if (store->getString(key.UTF8String, value, false)) {
                    NSString *stringValue = JohnString(value);
                    if (stringValue) values[key] = stringValue;
                }
            }
            return @{ @"keys": keys, @"stringValues": values };
        } catch (const std::exception &exception) {
            if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:3
                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:exception.what()] ?: @"MMKV read failed."}];
            return nil;
        } catch (...) {
            if (error) *error = [NSError errorWithDomain:JohnLegacyMMKVErrorDomain code:4
                userInfo:@{NSLocalizedDescriptionKey: @"MMKV read failed."}];
            return nil;
        }
    }
}
