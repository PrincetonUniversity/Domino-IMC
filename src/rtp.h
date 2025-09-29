#ifndef WEBRTC_CELLULAR_RTP_H
#define WEBRTC_CELLULAR_RTP_H

#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <optional>
#include <ostream>
#include <sstream>
#include <arpa/inet.h>

namespace rtp {

    static const unsigned HDR_LEN = 12;

    static bool contains_rtp(const unsigned char* buf, const std::size_t len) {

        // https://www.rfc-editor.org/rfc/rfc5761#section-4

        return len >= 12 && ((buf[0] >> 6) & 0x03) == 0x02 && (buf[1] <= 191 || buf[1] >= 224);
    }

    static bool contains_rtcp(const unsigned char* buf, const std::size_t len) {

        return len >= 12 && ((buf[0] >> 6) & 0x03) == 0x02 && (buf[1] >= 200 && buf[1] <= 205);
    }

    static bool contains_rtp_or_rtcp(const unsigned char* buf, std::size_t len) {

        return len >= 12 && ((buf[0] >> 6) & 0x03) == 0x02;
    }

    struct hdr {

        // https://datatracker.ietf.org/doc/html/rfc3550#section-5.1

        std::uint8_t  v_p_x_cc = 0;
        std::uint8_t  m_pt     = 0;
        std::uint16_t seq      = 0;
        std::uint32_t ts       = 0;
        std::uint32_t ssrc     = 0;

        [[nodiscard]] unsigned version() const {
            return (v_p_x_cc >> 6) & 0x03;
        }

        [[nodiscard]] unsigned padding() const {
            return (v_p_x_cc >> 5) & 0x01;
        }

        [[nodiscard]] unsigned extension() const {
            return (v_p_x_cc >> 4) & 0x01;
        }

        [[nodiscard]] unsigned csrc_count() const {
            return v_p_x_cc & 0x0f;
        }

        [[nodiscard]] unsigned marker() const {
            return m_pt >> 7 & 0x01;
        }

        [[nodiscard]] unsigned payload_type() const {
            return m_pt & 0x7f;
        }
    };

    struct ext {
        unsigned short type = 0, len = 0;
        unsigned char data[64] = {0};

        bool operator==(const struct ext& other) const {
            return type == other.type && len == other.len
                   && std::strncmp((const char*) data, (const char*) other.data, len) == 0;
        }

        inline bool operator!=(const struct ext& other) const {
            return !(*this == other);
        }

        [[nodiscard]] std::string to_string() const {

            std::stringstream ss;

            for (auto i = 0; i < len; i++) {
                ss << std::hex << std::setw(2) << std::setfill('0') << (unsigned) data[i];
            }

            return ss.str();
        }
    };

    static std::uint16_t ext_profile(const rtp::hdr* hdr) {

        if (!hdr->extension())
            throw std::logic_error("rtp::has_one_byte_ext_headers: no extensions");

        const auto* ext_buf = reinterpret_cast<const unsigned char*>(hdr) + rtp::HDR_LEN;

        return ntohs(*(std::uint16_t*) ext_buf);
    }

    static bool has_one_byte_ext_headers(const rtp::hdr* hdr) {

        // https://www.rfc-editor.org/rfc/rfc8285.html#section-4.2

        return ext_profile(hdr) == 0xbede;
    }

    static bool has_two_byte_ext_headers(const rtp::hdr* hdr) {

        // https://www.rfc-editor.org/rfc/rfc8285.html#section-4.3

        return (ext_profile(hdr) >> 4) == 0x100;
    }

    /// returns a std::optional wrapping a struct ext representing the extension header with
    /// identifier type from header hdr
    ///   - returns std::nullopt if extension header does not exist
    ///   - handles both one- and two-byte extension headers
    static std::optional<struct ext> get_ext(const rtp::hdr* hdr, unsigned type) {

        struct ext ext;
        const auto* ext_buf = reinterpret_cast<const unsigned char*>(hdr) + rtp::HDR_LEN;
        bool has_one_byte_ext_headers = rtp::has_one_byte_ext_headers(hdr);

        if (hdr->csrc_count() == 0 && hdr->extension() == 1) {

            std::uint16_t ext_total_len = ((ext_buf[2] << 8) + (ext_buf[3])) * 4;

            for (unsigned i = 4; i < ext_total_len + 4;) {

                if (ext_buf[i] != 0) {

                    unsigned short ext_type = 0, ext_len = 0;

                    if (has_one_byte_ext_headers) {
                        ext_type = (ext_buf[i] >> 4) & 0x0f;
                        ext_len  = (ext_buf[i] & 0x0f) + 1;
                    } else {
                        ext_type = ext_buf[i];
                        ext_len  = ext_buf[i+1];
                    }

                    if (ext_type == type) {
                        ext.type = ext_type;
                        ext.len = ext_len;
                        std::memcpy(ext.data, ext_buf + i + (has_one_byte_ext_headers ? 1 : 2),
                                    ext.len);
                        return ext;
                    }

                    i += (ext_len + (has_one_byte_ext_headers ? 1 : 2));

                } else { // padding
                    i++;
                }
            }
        }

        return std::nullopt;
    }

    /// returns the total length in bytes of RTP extension headers including padding but excluding
    /// the 4-byte extension header starting with 0xbede
    static unsigned total_ext_len(const rtp::hdr* hdr) {

        const auto* buf = reinterpret_cast<const unsigned char*>(hdr);
        const auto* ext_buf = buf + 12;

        if (hdr->csrc_count() == 0 && hdr->extension() == 1) {
            return ((ext_buf[2] << 8) + (ext_buf[3])) * 4;
        } else {
            return 0;
        }
    }

    static std::optional<std::uint32_t> get_abs_send_time(const rtp::hdr* hdr, unsigned type) {

        auto ext = get_ext(hdr, type);

        if (ext && ext->len == 3) {
            return (ext->data[0] << 16) | (ext->data[1] << 8) | (ext->data[2]);
        }

        return std::nullopt;
    }

    static std::optional<unsigned> get_abs_send_time_ms(const rtp::hdr* hdr, unsigned type) {

        auto value = get_abs_send_time(hdr, type);

        if (value) {

            // 6.18 fixed-point encoding - 6 bits for seconds, 18 bits for fraction

            unsigned sec = (*value >> 18);
            unsigned frac = (*value & 0x3ffff);
            double ms = (double) frac / (1 << 18) * 1000;
            return (unsigned) (sec * 1000) + ms;
        }

        return std::nullopt;
    }

    static std::optional<std::uint32_t> get_transport_cc_seq(const rtp::hdr* hdr, unsigned type) {

        auto ext = get_ext(hdr, type);

        if (ext && ext->len == 2) {
            return (ext->data[0] << 8) | (ext->data[1]);
        }

        return std::nullopt;
    }

    static std::ostream& operator<<(std::ostream& os, const rtp::hdr& rtp) {
        os << "rtp: v=" << std::dec << rtp.version()
           << ",p=" << std::dec << rtp.padding()
           << ",x=" << std::dec << rtp.extension()
           << ",cc=" << std::dec << rtp.csrc_count()
           << ",m=" << std::dec << rtp.marker()
           << ",pt=" << std::dec << rtp.payload_type()
           << ",seq=" << std::dec << ntohs(rtp.seq)
           << ",ts=" << std::dec << ntohl(rtp.ts)
           << ",ssrc=0x" << std::hex << std::setw(8) << std::setfill('0')
           << ntohl(rtp.ssrc) << std::dec;

        return os;
    }
}

#endif