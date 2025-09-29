#ifndef WEBRTC_CELLULAR_RTCP_TWCC_H
#define WEBRTC_CELLULAR_RTCP_TWCC_H

#include <cstdint>
#include <ostream>
#include <arpa/inet.h>

namespace rtcp::twcc {

    enum class chunk_type : std::uint16_t {
        run_length    = 0,
        status_vector = 1
    };

    inline chunk_type chunk_type(const unsigned char* buf) {
        return static_cast<enum chunk_type>(ntohs(*buf) >> 15);
    }

    //! Packet status in one-bit format
    enum class one_bit_status_symbol : std::uint16_t {
        received     = 0,
        not_received = 1
    };

    //! Packet status in two-bit format
    //!
    //! Packets with status "Packet not received" should not necessarily be interpreted as lost.
    //! They might just not have arrived yet. For each packet received with a delta, to the
    //! previous received packet, within +/-8191.75ms, a receive delta block is appended to the
    //! feedback message.
    enum class two_bit_status_symbol : std::uint16_t {
        not_received         = 0b00,
        received_small_delta = 0b01,
        received_large_delta = 0b10,
        reserved             = 0b11
    };

    inline std::ostream& operator<<(std::ostream& os, const two_bit_status_symbol& symbol) {
        switch (symbol) {
            case two_bit_status_symbol::not_received:
                os << "not_received";
                break;
            case two_bit_status_symbol::received_small_delta:
                os << "received_small_delta";
                break;
            case two_bit_status_symbol::received_large_delta:
                os << "received_large_delta";
                break;
            case two_bit_status_symbol::reserved:
                os << "reserved";
                break;
        }
        return os;
    }

    enum class symbol_size : std::uint16_t {
        one_bit  = 0,
        two_bits = 1
    };

    struct hdr {

        static constexpr unsigned LEN = 20;

        std::uint8_t v_p_fmt = 0;
        std::uint8_t pt = 0;
        std::uint16_t length = 0;
        std::uint32_t sender_ssrc = 0;
        std::uint32_t media_ssrc = 0;
        std::uint16_t base_seq = 0;
        std::uint16_t packet_status_count = 0;
        std::uint32_t ref_time_fp_pkt_count = 0;


        //! Returns the reference time in multiples of 64ms.
        //!
        //! 24 bits Signed integer indicating an absolute reference time in some (unknown) time
        //! base chosen by the sender of the feedback packets. The value is to be interpreted
        //! in multiples of 64ms. The first recv delta in this packet is relative to the
        //! reference time. The reference time makes it possible to calculate the delta between
        //! feedbacks even if some feedback packets are lost, since it always uses the same
        //! time base.
        [[nodiscard]] std::uint32_t ref_time() const {
            return (ntohl(ref_time_fp_pkt_count) >> 8) & 0x00ffffff;
        }

        [[nodiscard]] std::uint8_t feedback_packet_count() const {
            return ntohl(ref_time_fp_pkt_count) & 0x000000ff;
        }
    };

    struct rl_chunk {

        static constexpr unsigned LEN = 2;

        std::uint16_t type_symbol_length = 0;

        [[nodiscard]] enum chunk_type type() const {
            return static_cast<enum chunk_type>(ntohs(type_symbol_length) >> 15);
        }

        [[nodiscard]] two_bit_status_symbol symbol() const {
            return static_cast<two_bit_status_symbol>(ntohs(type_symbol_length) >> 13);
        }

        [[nodiscard]] std::uint16_t length() const {
            return ntohs(type_symbol_length) & 0x1fff;
        }
    };

    struct sv_chunk {

        static constexpr unsigned LEN = 2;

        std::uint16_t type_symbol_size_symbol_list = 0;

        [[nodiscard]] enum chunk_type type() const {
            return static_cast<enum chunk_type>(ntohs(type_symbol_size_symbol_list) >> 15);
        }

        //! Returns the size of the symbols in this vector.
        //!
        //! A zero means this vector contains only "packet received" (0) and "packet not
        //! received" (1) symbols. This means we can compress each symbol to just one bit,
        //! 14 in total. A one means this vector contains the normal 2-bit symbols, 7 in total.
        [[nodiscard]] enum symbol_size symbol_size() const {
            return static_cast<enum symbol_size>(
                (ntohs(type_symbol_size_symbol_list) >> 14) & 1);
        }

        [[nodiscard]] unsigned n_symbols() const {
            return symbol_size() == symbol_size::two_bits ? 7 : 14;
        }

        [[nodiscard]] std::uint16_t symbol_list() const {
            return ntohs(type_symbol_size_symbol_list) & 0x3fff;
        }
    };

    struct small_delta {
        static constexpr unsigned LEN = 1;
        std::uint8_t delta = 0;
    };

    struct large_delta {
        static constexpr unsigned LEN = 2;
        std::uint16_t delta = 0;
    };
}


#endif
