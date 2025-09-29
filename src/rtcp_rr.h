#ifndef WEBRTC_CELLULAR_RTCP_RR_H
#define WEBRTC_CELLULAR_RTCP_RR_H

#include <cstdint>
#include <stdexcept>

namespace rtcp {

    struct rr {

        static const unsigned LEN = 24;

        //! SSRC this receiver report is about
        std::uint32_t ssrc                = 0;
        //! 8 bits fraction lost, 24 bits cumulative lost
        std::uint32_t frac_lost_cum_lost  = 0;
        //! extended highest sequence number received
        std::uint32_t ext_highest_seq_num = 0;
        //! interarrival jitter
        std::uint32_t jitter              = 0;
        //! last SR
        std::uint32_t lsr                 = 0;
        //! delay since last SR
        std::uint32_t dlsr                = 0;

        //! returns the numerator (0-255) of the fraction of packets lost
        [[nodiscard]] unsigned frac_lost() const {
            return (frac_lost_cum_lost >> 24) & 0xff;
        }

        //! returns the total number of packets lost
        [[nodiscard]] unsigned cum_lost() const {
            return frac_lost_cum_lost & 0x00ffffff;
        }
    };
}

#endif
