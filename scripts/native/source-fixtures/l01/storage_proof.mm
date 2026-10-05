#import <Foundation/Foundation.h>
#include <sqlite3.h>
#include <CommonCrypto/CommonDigest.h>
#include <zlib.h>
#include "MMKV.h"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <thread>

namespace fs = std::filesystem;
constexpr size_t kMaxSectionJSONBytes = 400000;

template <typename F> struct Cleanup { F action; ~Cleanup() { action(); } };
template <typename F> static Cleanup<F> onExit(F action) { return {action}; }

static void require(bool condition, const std::string &message) {
  if (!condition) throw std::runtime_error(message);
}

static bool pathContains(const fs::path &parent, const fs::path &child) {
  auto p = fs::absolute(parent).lexically_normal();
  auto c = fs::absolute(child).lexically_normal();
  auto pi = p.begin(), ci = c.begin();
  for (; pi != p.end() && ci != c.end(); ++pi, ++ci) if (*pi != *ci) return false;
  return pi == p.end();
}

static void requireDisjointPaths(const fs::path &output, const fs::path &mmkv, const fs::path &search, const fs::path &works) {
  const fs::path out = fs::absolute(output).lexically_normal();
  for (const fs::path &protectedPath : {fs::absolute(mmkv).lexically_normal(), fs::absolute(search).lexically_normal(), fs::absolute(works).lexically_normal()}) {
    require(!pathContains(out, protectedPath) && !pathContains(protectedPath, out),
            "output path overlaps a protected MMKV or database path: " + protectedPath.string());
  }
}

static NSString *ns(const std::string &value) {
  return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding];
}

static std::string sha256File(const fs::path &path) {
  NSData *data = [NSData dataWithContentsOfFile:ns(path.string())];
  require(data != nil, "cannot read hash input " + path.string());
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  static const char hex[] = "0123456789abcdef";
  std::string result; result.reserve(CC_SHA256_DIGEST_LENGTH * 2);
  for (unsigned char byte : digest) { result.push_back(hex[byte >> 4]); result.push_back(hex[byte & 0x0f]); }
  return result;
}

static bool isParagraphArray(const std::string &json, size_t *countOut = nullptr) {
  @autoreleasepool {
    NSData *data = [NSData dataWithBytes:json.data() length:json.size()];
    NSError *error = nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:&error];
    if (error || ![value isKindOfClass:[NSArray class]]) return false;
    NSArray *items = (NSArray *)value;
    for (id item in items) if (![item isKindOfClass:[NSString class]]) return false;
    if (countOut) *countOut = items.count;
    return true;
  }
}

static std::string inflateBounded(const unsigned char *bytes, size_t length, size_t maxBytes) {
  require(length > 0, "zlib input is empty");
  std::string output(maxBytes, '\0');
  uLongf outputLength = (uLongf)maxBytes;
  const int status = uncompress((Bytef *)output.data(), &outputLength, bytes, (uLong)length);
  if (status == Z_BUF_ERROR) throw std::runtime_error("decoded section exceeds byte bound");
  require(status == Z_OK, "zlib decode failed with status " + std::to_string(status));
  output.resize(outputLength);
  return output;
}

static std::string decodeSection(sqlite3_stmt *row, size_t maxBytes) {
  const int type = sqlite3_column_type(row, 3);
  if (type == SQLITE_TEXT) {
    const auto *text = (const char *)sqlite3_column_text(row, 3);
    const int size = sqlite3_column_bytes(row, 3);
    require(text != nullptr || size == 0, "TEXT paragraph pointer is null");
    require(size >= 0 && (size_t)size <= maxBytes, "TEXT section exceeds byte bound");
    return size == 0 ? std::string() : std::string(text, (size_t)size);
  }
  require(type == SQLITE_BLOB, "paragraphs column must be BLOB or TEXT");
  const auto *data = (const unsigned char *)sqlite3_column_blob(row, 3);
  const int size = sqlite3_column_bytes(row, 3);
  require(data != nullptr && size > 0, "BLOB paragraph pointer or size is invalid");
  return inflateBounded(data, (size_t)size, maxBytes);
}

static sqlite3 *openDatabase(const std::string &path, int flags) {
  sqlite3 *db = nullptr;
  const int result = sqlite3_open_v2(path.c_str(), &db, flags, nullptr);
  if (result != SQLITE_OK) {
    std::string error = db ? sqlite3_errmsg(db) : "no SQLite handle";
    if (db) sqlite3_close(db);
    throw std::runtime_error("SQLite open failed: " + error);
  }
  return db;
}

static std::string scalarText(sqlite3_stmt *stmt, int column) {
  const auto *value = (const char *)sqlite3_column_text(stmt, column);
  return value ? value : "";
}

static void createMMKVFixture(const std::string &root) {
  fs::create_directories(root);
  MMKVPath_t rootPath = root;
  MMKV::initializeMMKV(rootPath, MMKVLogNone);
  auto *store = MMKV::mmkvWithID("mmkv.default", MMKV_SINGLE_PROCESS, nullptr, &rootPath);
  require(store != nullptr, "MMKV fixture open failed");
  require(store->set(std::string("\"small\""), "bible.reader.textSize"), "MMKV write failed");
  require(store->set(std::string("{\"completedDays\":[1,3],\"selectedDay\":3,\"intention\":\"synthetic\"}"), "novena.synthetic.progress.v1"), "MMKV write failed");
  require(store->set(std::string("{\"before\":\"before text\",\"after\":\"after text\"}"), "vesper.sunday.2026-10-05"), "MMKV write failed");
  store->sync(MMKV_SYNC);
  store->close();
}

static void readMMKVFixture(const std::string &root, const std::vector<std::string> &expectedKeys) {
  const fs::path dataFile = fs::path(root) / "mmkv.default";
  const fs::path crcFile = fs::path(root) / "mmkv.default.crc";
  require(fs::is_regular_file(dataFile) && fs::is_regular_file(crcFile), "MMKV data or CRC file is missing");
  const auto dataBefore = sha256File(dataFile);
  const auto crcBefore = sha256File(crcFile);
  MMKVPath_t rootPath = root;
  MMKV::initializeMMKV(rootPath, MMKVLogNone);
  auto *store = MMKV::mmkvWithID("mmkv.default", (MMKVMode)(MMKV_SINGLE_PROCESS | MMKV_READ_ONLY), nullptr, &rootPath);
  require(store != nullptr && store->isReadOnly(), "MMKV adapter did not open read-only");
  for (const auto &key : expectedKeys) {
    std::string value;
    require(store->getString(key, value, false), "MMKV expected key was not found: " + key);
  }
  store->close();
  const auto dataAfter = sha256File(dataFile);
  const auto crcAfter = sha256File(crcFile);
  require(dataBefore == dataAfter && crcBefore == crcAfter, "read-only MMKV open changed data or CRC bytes");
  std::cout << "MMKV v2 read-only: keys=" << expectedKeys.size() << ", id=mmkv.default, encryptionKeySupplied=false, dataSha256=" << dataBefore << ", crcSha256=" << crcBefore << ", unchanged=true\n";
}

static void proveSQLiteBackup(const std::string &directory) {
  const std::string sourcePath = directory + "/live-wal.sqlite";
  const std::string backupPath = directory + "/sqlite-backup.sqlite";
  fs::remove(sourcePath); fs::remove(sourcePath + "-wal"); fs::remove(sourcePath + "-shm"); fs::remove(backupPath);
  sqlite3 *source = openDatabase(sourcePath, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE);
  auto sourceCleanup = onExit([&] { if (source) sqlite3_close_v2(source); });
  char *error = nullptr;
  auto errorCleanup = onExit([&] { if (error) sqlite3_free(error); });
  require(sqlite3_exec(source, "PRAGMA journal_mode=WAL; CREATE TABLE evidence(value TEXT NOT NULL); BEGIN; INSERT INTO evidence VALUES('committed-before-backup'); COMMIT;", nullptr, nullptr, &error) == SQLITE_OK,
          std::string("WAL setup failed: ") + (error ? error : "unknown"));
  if (error) { sqlite3_free(error); error = nullptr; }
  require(fs::exists(sourcePath + "-wal"), "WAL file is not present during backup proof");
  sqlite3 *destination = openDatabase(backupPath, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE);
  auto destinationCleanup = onExit([&] { if (destination) sqlite3_close_v2(destination); });
  sqlite3_backup *backup = sqlite3_backup_init(destination, "main", source, "main");
  auto backupCleanup = onExit([&] { if (backup) sqlite3_backup_finish(backup); });
  require(backup != nullptr, "sqlite3_backup_init failed");
  int status = SQLITE_OK;
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  do {
    status = sqlite3_backup_step(backup, -1);
    if (status == SQLITE_BUSY || status == SQLITE_LOCKED) {
      if (std::chrono::steady_clock::now() >= deadline) {
        sqlite3_backup_finish(backup); backup = nullptr;
        throw std::runtime_error("SQLite backup exceeded 5 second deadline");
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
  } while (status == SQLITE_OK || status == SQLITE_BUSY || status == SQLITE_LOCKED);
  const int finish = sqlite3_backup_finish(backup);
  backup = nullptr;
  require(status == SQLITE_DONE && finish == SQLITE_OK, "SQLite backup did not finish");
  sqlite3_stmt *query = nullptr;
  auto queryCleanup = onExit([&] { if (query) sqlite3_finalize(query); });
  require(sqlite3_prepare_v2(destination, "SELECT value FROM evidence", -1, &query, nullptr) == SQLITE_OK, "backup verification query failed");
  require(sqlite3_step(query) == SQLITE_ROW && scalarText(query, 0) == "committed-before-backup", "backup omitted a committed WAL row");
  sqlite3_finalize(query); query = nullptr;
  sqlite3_close_v2(destination); destination = nullptr;
  sqlite3_close_v2(source); source = nullptr;
  std::cout << "SQLite online backup: committed WAL row preserved\n";
}

static void proveFTS(const std::string &path) {
  sqlite3 *db = openDatabase(path, SQLITE_OPEN_READONLY);
  auto dbCleanup = onExit([&] { if (db) sqlite3_close_v2(db); });
  sqlite3_stmt *query = nullptr;
  auto queryCleanup = onExit([&] { if (query) sqlite3_finalize(query); });
  const char *sql = "SELECT verses.translation_id, verses.book_name, verses.chapter, verses.verse FROM verse_search JOIN verses ON verses.id = verse_search.rowid WHERE verse_search MATCH ? AND verses.translation_id = ? ORDER BY bm25(verse_search), verses.book_order, verses.chapter, verses.verse_order LIMIT 3";
  require(sqlite3_prepare_v2(db, sql, -1, &query, nullptr) == SQLITE_OK, "FTS5 query did not prepare");
  const char *editions[] = {"web-ce", "douay-rheims", "vulgate"};
  const char *terms[] = {"beginning", "light", "lux"};
  for (int i = 0; i < 3; ++i) {
    require(sqlite3_reset(query) == SQLITE_OK, "FTS5 query reset failed");
    require(sqlite3_clear_bindings(query) == SQLITE_OK, "FTS5 query clear bindings failed");
    require(sqlite3_bind_text(query, 1, terms[i], -1, SQLITE_STATIC) == SQLITE_OK, "FTS5 term bind failed");
    require(sqlite3_bind_text(query, 2, editions[i], -1, SQLITE_STATIC) == SQLITE_OK, "FTS5 edition bind failed");
    require(sqlite3_step(query) == SQLITE_ROW, std::string("FTS5 query returned no result for ") + editions[i]);
    std::cout << "SQLite FTS5: edition=" << scalarText(query, 0) << ", term=" << terms[i] << ", result=" << scalarText(query, 1) << " " << sqlite3_column_int(query, 2) << ":" << scalarText(query, 3) << "\n";
  }
  sqlite3_finalize(query); query = nullptr; sqlite3_close_v2(db); db = nullptr;
}

static void proveWorks(const std::string &path, const std::string &directory, bool fullAudit, const std::string &workId, int sectionIndex) {
  sqlite3 *db = openDatabase(path, SQLITE_OPEN_READONLY);
  auto dbCleanup = onExit([&] { if (db) sqlite3_close_v2(db); });
  sqlite3_stmt *maxQuery = nullptr;
  auto maxQueryCleanup = onExit([&] { if (maxQuery) sqlite3_finalize(maxQuery); });
  const char *querySql = fullAudit ? "SELECT work_id, idx, '', paragraphs FROM sections" : "SELECT work_id, idx, '', paragraphs FROM sections WHERE work_id = ? AND idx = ?";
  require(sqlite3_prepare_v2(db, querySql, -1, &maxQuery, nullptr) == SQLITE_OK, "works scan did not prepare");
  if (!fullAudit) {
    require(sqlite3_bind_text(maxQuery, 1, workId.c_str(), -1, SQLITE_TRANSIENT) == SQLITE_OK, "works ID bind failed");
    require(sqlite3_bind_int(maxQuery, 2, sectionIndex) == SQLITE_OK, "works section bind failed");
  }
  size_t maxDecoded = 0; std::string maxWork; int maxIndex = -1; size_t sectionCount = 0;
  int stepStatus = SQLITE_OK;
  while ((stepStatus = sqlite3_step(maxQuery)) == SQLITE_ROW) {
    std::string decoded = decodeSection(maxQuery, kMaxSectionJSONBytes);
    size_t paragraphs = 0;
    require(isParagraphArray(decoded, &paragraphs), "works section is not a JSON string array");
    if (decoded.size() > maxDecoded) { maxDecoded = decoded.size(); maxWork = scalarText(maxQuery, 0); maxIndex = sqlite3_column_int(maxQuery, 1); }
    ++sectionCount;
  }
  require(stepStatus == SQLITE_DONE, "works scan failed: " + std::string(sqlite3_errmsg(db)));
  sqlite3_finalize(maxQuery); maxQuery = nullptr;
  if (fullAudit) require(sectionCount == 16146, "unexpected works section count");
  else require(sectionCount == 1, "requested works section was not found exactly once");
  require(maxDecoded <= kMaxSectionJSONBytes, "max section output exceeded configured limit");

  const std::string legacyPath = directory + "/legacy-text.sqlite";
  fs::remove(legacyPath);
  sqlite3 *legacy = openDatabase(legacyPath, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE);
  auto legacyCleanup = onExit([&] { if (legacy) sqlite3_close_v2(legacy); });
  char *error = nullptr;
  auto legacyErrorCleanup = onExit([&] { if (error) sqlite3_free(error); });
  require(sqlite3_exec(legacy, "CREATE TABLE sections(idx INTEGER, title TEXT, words INTEGER, paragraphs BLOB); INSERT INTO sections VALUES(0,'legacy',2,'[\"legacy paragraph\"]');", nullptr, nullptr, &error) == SQLITE_OK,
          std::string("legacy TEXT setup failed: ") + (error ? error : "unknown"));
  if (error) { sqlite3_free(error); error = nullptr; }
  sqlite3_stmt *textRow = nullptr;
  auto textRowCleanup = onExit([&] { if (textRow) sqlite3_finalize(textRow); });
  require(sqlite3_prepare_v2(legacy, "SELECT idx,title,words,paragraphs FROM sections", -1, &textRow, nullptr) == SQLITE_OK && sqlite3_step(textRow) == SQLITE_ROW, "legacy TEXT row missing");
  std::string plain = decodeSection(textRow, kMaxSectionJSONBytes);
  require(sqlite3_column_type(textRow, 3) == SQLITE_TEXT && isParagraphArray(plain), "legacy TEXT paragraph decode failed");
  sqlite3_finalize(textRow); textRow = nullptr; sqlite3_close_v2(legacy); legacy = nullptr;

  sqlite3 *textTestDb = openDatabase(":memory:", SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE);
  auto textTestDbCleanup = onExit([&] { if (textTestDb) sqlite3_close_v2(textTestDb); });
  sqlite3_stmt *oversizedText = nullptr;
  auto oversizedTextCleanup = onExit([&] { if (oversizedText) sqlite3_finalize(oversizedText); });
  require(sqlite3_prepare_v2(textTestDb, "SELECT 0, '', 0, CAST(? AS TEXT)", -1, &oversizedText, nullptr) == SQLITE_OK, "oversized TEXT fixture did not prepare");
  const std::string oversizedPayload(kMaxSectionJSONBytes + 1, 'x');
  require(sqlite3_bind_text(oversizedText, 1, oversizedPayload.data(), (int)oversizedPayload.size(), SQLITE_TRANSIENT) == SQLITE_OK, "oversized TEXT fixture bind failed");
  require(sqlite3_step(oversizedText) == SQLITE_ROW, "oversized TEXT fixture row missing");
  bool textBoundRejected = false;
  try { (void)decodeSection(oversizedText, kMaxSectionJSONBytes); }
  catch (const std::runtime_error &) { textBoundRejected = true; }
  require(textBoundRejected, "oversized TEXT fixture was not rejected");
  sqlite3_finalize(oversizedText); oversizedText = nullptr; sqlite3_close_v2(textTestDb); textTestDb = nullptr;

  const std::string damagedJson(500001, 'x');
  uLongf compressedLength = compressBound((uLong)damagedJson.size());
  std::vector<unsigned char> compressed(compressedLength);
  require(compress2(compressed.data(), &compressedLength, (const Bytef *)damagedJson.data(), (uLong)damagedJson.size(), Z_BEST_SPEED) == Z_OK, "damaged fixture compression failed");
  bool boundRejected = false;
  try { (void)inflateBounded(compressed.data(), compressedLength, kMaxSectionJSONBytes); }
  catch (const std::runtime_error &) { boundRejected = true; }
  require(boundRejected, "oversized damaged fixture was not rejected");
  const unsigned char bad[] = {0x01, 0x02, 0x03, 0x04};
  bool corruptRejected = false;
  try { (void)inflateBounded(bad, sizeof(bad), kMaxSectionJSONBytes); }
  catch (const std::runtime_error &) { corruptRejected = true; }
  require(corruptRejected, "damaged zlib fixture was not rejected");
  sqlite3_close_v2(db); db = nullptr;
  std::cout << "Works decode: rows=" << sectionCount << ", largestDecodedBytes=" << maxDecoded << ", work=" << maxWork << ", section=" << maxIndex << ", textFallback=passed, oversizedTextFixture=rejected, oversizedBlobFixture=rejected, damagedZlib=rejected\n";
}

int main(int argc, char **argv) {
  @autoreleasepool {
    try {
      require(argc >= 6, "usage: storage-proof <synthetic-create|legacy-read|host-audit> <search.db> <works.db> <output-dir> <mmkv-root> [expected-keys-csv] [work-id section-index]");
      const std::string mode = argv[1], search = argv[2], works = argv[3], out = argv[4], location = argv[5];
      if (mode == "synthetic-create") {
        requireDisjointPaths(out, location, search, works);
        const fs::path target(location);
        require(!fs::exists(target), "synthetic MMKV output path already exists; refusing to modify it");
        fs::create_directories(target.parent_path());
        createMMKVFixture(location);
        readMMKVFixture(location, {"bible.reader.textSize", "novena.synthetic.progress.v1", "vesper.sunday.2026-10-05"});
        std::cout << "Synthetic MMKV fixture created at output-only path.\n";
        return 0;
      }
      require(mode == "legacy-read" || mode == "host-audit", "unknown proof mode");
      const std::string mmkv = location;
      requireDisjointPaths(out, mmkv, search, works);
      std::vector<std::string> keys;
      if (argc > 6 && std::string(argv[6]).size()) {
        std::string list = argv[6]; size_t start = 0;
        while (start < list.size()) { size_t comma = list.find(',', start); keys.push_back(list.substr(start, comma == std::string::npos ? comma : comma - start)); if (comma == std::string::npos) break; start = comma + 1; }
      }
      require(mode == "host-audit" || argc >= 9, "legacy-read requires expected-keys-csv, work-id, and section-index arguments");
      fs::create_directories(out);
      readMMKVFixture(mmkv, keys);
      proveFTS(search);
      const bool fullAudit = mode == "host-audit";
      proveWorks(works, out, fullAudit, fullAudit ? "" : argv[7], fullAudit ? -1 : std::stoi(argv[8]));
      if (fullAudit) proveSQLiteBackup(out);
      std::cout << (fullAudit ? "Host-only full-corpus audit complete." : "One-section legacy-read proof complete.") << " No simulator was opened.\n";
      return 0;
    } catch (const std::exception &e) {
      std::cerr << "storage-proof: " << e.what() << "\n";
      return 1;
    }
  }
}
