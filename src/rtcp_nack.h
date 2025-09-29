#ifndef WEBRTC_CELLULAR_RTCP_NACK_H
#define WEBRTC_CELLULAR_RTCP_NACK_H

#include <cstdint>
#include <ostream>
#include <arpa/inet.h>

namespace rtcp::nack {

    struct hdr {

        static constexpr unsigned LEN = 12;

        std::uint8_t v_p_fmt = 0;
        std::uint8_t pt = 0;
        std::uint16_t length = 0;
        std::uint32_t sender_ssrc = 0;
        std::uint32_t media_ssrc = 0;

        [[nodiscard]] unsigned nack_block_count() const {
            return (ntohs(length) * 4 + 4 - LEN) / 4;
        }
    };

    struct nack_block {

        static constexpr unsigned LEN = 4;

        std::uint16_t pid = 0;
        std::uint16_t blp = 0;
    };

}

#endif