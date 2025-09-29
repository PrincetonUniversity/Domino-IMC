
#ifndef WEBRTC_CELLULAR_UTIL_H
#define WEBRTC_CELLULAR_UTIL_H

#include <cstdint>
#include <stdexcept>
#include <utility>
#include <vector>

namespace util {
    static std::uint32_t extractBits(const std::vector<bool>& bits, unsigned from, unsigned len = 1) {

        if (from + len > bits.size())
            throw std::invalid_argument("util:extractBits: requested range outside of bit vector");

        if (len > 32 || len < 1)
            throw std::invalid_argument("util:extractBits: len must be > 0 and <= 32");

        std::uint32_t a = 0;

        for (auto i = from, j = len - 1; i < from + len; i++, j--)
            a |= (bits[i] << j);

        return a;
    }

    static std::pair<std::uint32_t, unsigned> extractNonSymmetric(const std::vector<bool>& bits,
                                                                  unsigned from, unsigned n) {

        unsigned w = 0, x = n;

        while (x != 0) {
            x = x >> 1;
            w++;
        }

        unsigned m = (1 << w) - n;

        std::uint32_t v = extractBits(bits, from, w - 1);

        if (v < m) {
            return std::make_pair(v, w-1);
        }

        unsigned extra_bit = extractBits(bits, from + w - 1, 1);

        return std::make_pair((v << 1) - m + extra_bit, w);
    }

}

#endif