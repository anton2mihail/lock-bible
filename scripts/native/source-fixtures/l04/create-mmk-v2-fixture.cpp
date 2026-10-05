#include "MMKV.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

static std::string decodeHex(const std::string &value) {
    if (value.size() % 2 != 0) throw std::runtime_error("hex field has an odd length");
    std::string decoded;
    decoded.reserve(value.size() / 2);
    for (size_t i = 0; i < value.size(); i += 2) {
        const auto byte = static_cast<char>(std::stoul(value.substr(i, 2), nullptr, 16));
        decoded.push_back(byte);
    }
    return decoded;
}

int main(int argc, char **argv) {
    try {
        if (argc != 3) throw std::runtime_error("usage: create-mmv2-fixture <new-mmkv-root> <hex-rows.tsv>");
        const std::filesystem::path root(argv[1]);
        if (std::filesystem::exists(root)) throw std::runtime_error("MMKV output path already exists");
        std::filesystem::create_directories(root);
        std::ifstream input(argv[2]);
        if (!input) throw std::runtime_error("fixture row file cannot be read");

        MMKVPath_t rootPath = root.string();
        MMKV::initializeMMKV(rootPath, MMKVLogNone);
        auto *store = MMKV::mmkvWithID("mmkv.default", MMKV_SINGLE_PROCESS, nullptr, &rootPath);
        if (!store) throw std::runtime_error("MMKV cannot create synthetic fixture");
        size_t rows = 0;
        std::string row;
        while (std::getline(input, row)) {
            if (row.empty()) continue;
            const auto separator = row.find('\t');
            if (separator == std::string::npos) throw std::runtime_error("fixture row has no tab separator");
            const auto key = decodeHex(row.substr(0, separator));
            const auto value = decodeHex(row.substr(separator + 1));
            if (!store->set(value, key)) throw std::runtime_error("MMKV fixture value write failed");
            ++rows;
        }
        store->close();
        if (rows == 0 || !std::filesystem::is_regular_file(root / "mmkv.default") ||
            !std::filesystem::is_regular_file(root / "mmkv.default.crc")) {
            throw std::runtime_error("MMKV fixture files were not created");
        }
        std::cout << "Created synthetic MMKV fixture: " << rows << " keys, id=mmkv.default\n";
        return 0;
    } catch (const std::exception &error) {
        std::cerr << "Fixture error: " << error.what() << '\n';
        return 1;
    }
}
