
#include <array>
#include <iostream>
#include <fstream>
#include <set>

#include <cxxopts/cxxopts.h>

#include "src/net.h"
#include "src/rtp.h"
#include "src/rtcp.h"
#include "src/pcap_file_reader.h"
#include "src/rtcp_rr.h"
#include "src/rtcp_twcc.h"
#include "src/rtcp_nack.h"

struct config {
    std::string input_file_path;
    std::string twcc_output_file_path;
    std::string nack_output_file_path;
    std::string rr_output_file_path;
    std::set<unsigned short> ports;
};

void print_help(cxxopts::Options& opts, int exit_code = 0) {

    std::ostream& os = (exit_code ? std::cerr : std::cout);
    os << opts.help({""}) << std::endl;
    exit(exit_code);
}

cxxopts::Options set_options() {

    cxxopts::Options opts("rtcp_pkts", "WebRTC RTCP Packet Printer");

    opts.add_options()
        ("i,in", "input file", cxxopts::value<std::string>(), "IN.pcap")
        ("t,twcc-out", "TWCC output file", cxxopts::value<std::string>(), "TWCC-OUT.csv")
        ("n,nack-out", "NACK output file", cxxopts::value<std::string>(), "NACK-OUT.csv")
        ("r,rr-out", "RR output file", cxxopts::value<std::string>(), "RR-OUT.csv")
        ("p,ports", "ports to filter on", cxxopts::value<std::string>(), "P1,P2,...")
        ("h,help", "print this help message");

    return opts;
}

config parse_options(cxxopts::Options opts, int argc, char** argv) {

    config config {};

    auto parsed = opts.parse(argc, argv);

    if (parsed.count("i")) {
        config.input_file_path = parsed["i"].as<std::string>();
    } else {
        print_help(opts, 1);
    }

    if (parsed.count("t")) {
        config.twcc_output_file_path = parsed["t"].as<std::string>();
    } else {
        print_help(opts, 1);
    }

    if (parsed.count("n")) {
        config.nack_output_file_path = parsed["n"].as<std::string>();
    } else {
        print_help(opts, 1);
    }

    if (parsed.count("r")) {
        config.rr_output_file_path = parsed["r"].as<std::string>();
    } else {
        print_help(opts, 1);
    }


    if (parsed.count("p")) {

        std::string token;
        std::istringstream token_stream{parsed["p"].as<std::string>()};

        while (std::getline(token_stream, token, ',')) {
            try {
                config.ports.insert(std::stoul(token));
            } catch (std::invalid_argument& e) {
                std::cerr << "error: invalid port number: " << token << std::endl;
                exit(1);
            }
        }

    } else {
        print_help(opts, 1);
    }

    if (parsed.count("h"))
        print_help(opts);

    return config;
}

[[nodiscard]] unsigned parse_udp(const pcap_pkt& pkt, const net::udp::hdr*& udp,
                                 const net::ipv4::hdr*& ipv4, const net::eth::hdr*& eth,
                                 const pcap_link_type& link_type) {

    unsigned offset = 0;

    if (link_type == pcap_link_type::eth) {

        // process ethernet header:

        eth = reinterpret_cast<const net::eth::hdr*>(pkt.buf);

        if (static_cast<net::eth::type>(ntohs(eth->ether_type)) != net::eth::type::ipv4) {
            return 0;
        }

        if ((offset += net::eth::HDR_LEN) >= pkt.cap_len) {
            return 0;
        }

    } else if (link_type == pcap_link_type::null) {

        // process null header:

        if ((offset += 4) >= pkt.cap_len) {
            return 0;
        }

    } else {
        // unsupported link type
        return 0;
    }

    // process ip header:

    ipv4 = reinterpret_cast<const net::ipv4::hdr*>(pkt.buf + offset);

    if (static_cast<net::ipv4::proto>(ipv4->next_proto_id) != net::ipv4::proto::udp) {
        return 0;
    }

    if ((offset += ipv4->ihl_bytes()) >= pkt.cap_len) {
        return 0;
    }

    // process udp header:

    udp = reinterpret_cast<const net::udp::hdr*>(pkt.buf + offset);

    if ((offset += net::udp::HDR_LEN) >= pkt.cap_len) {
        return 0;
    }

    return offset;
}

int main(int argc, char** argv) {

    auto config = parse_options(set_options(), argc, argv);

    pcap_pkt pkt;
    pcap_file_reader pcap_in(config.input_file_path);

    if (pcap_in.datalink_type() != pcap_link_type::eth
        && pcap_in.datalink_type() != pcap_link_type::null) {
        std::cerr << "error: only ethernet supported right now, exiting." << std::endl;
        exit(1);
    }

    std::cout << " - input file: " << config.input_file_path << std::endl;
    std::cout << " - twcc output file: " << config.twcc_output_file_path << std::endl;
    std::cout << " - nack output file: " << config.nack_output_file_path << std::endl;
    std::cout << " - rr output file: " << config.rr_output_file_path << std::endl;
    std::cout << " - filter udp ports:";
    for (auto port : config.ports) {
        std::cout << " " << port;
    }
    std::cout << std::endl;

    std::ofstream twcc_csv_out(config.twcc_output_file_path);
    std::ofstream nack_csv_out(config.nack_output_file_path);
    std::ofstream rr_csv_out(config.rr_output_file_path);

    struct { unsigned long pkts_in = 0, lines_out = 0, skipped = 0,
             twcc_msgs = 0, nack_msgs = 0, rr_msgs = 0; } counters;

    twcc_csv_out << "ts_s,ts_us,ip_src,ip_dst,udp_src,udp_dst,sender_ssrc,media_ssrc,fb_pkt_cnt,"
                 << "rtp_tw_seq,rxd,rx_time" << std::endl;

    nack_csv_out << "ts_s,ts_us,nack_pkt,ip_src,ip_dst,udp_src,udp_dst,pid,blp_count" << std::endl;

    rr_csv_out << "ts_s,ts_us,ip_src,ip_dst,udp_src,udp_dst,sender_ssrc,ssrc,jitter,frac_lost,"
               << "cum_lost" << std::endl;

    std::vector<rtcp::twcc::two_bit_status_symbol> two_bit_symbols;
    two_bit_symbols.resize(128);

    while (pcap_in.next(pkt)) {
        counters.pkts_in++;

        const net::eth::hdr* eth = nullptr;
        const net::ipv4::hdr* ipv4 = nullptr;
        const net::udp::hdr* udp = nullptr;

        auto offset = parse_udp(pkt, udp, ipv4, eth, pcap_in.datalink_type());

        if (offset == 0) {
            counters.skipped++;
            continue;
        }

        if (udp == nullptr) {
            counters.skipped++;
            continue;
        }

        // filter for udp port numbers:

        if (config.ports.find(ntohs(udp->src_port)) == config.ports.end()
            && config.ports.find(ntohs(udp->dst_port)) == config.ports.end()) {
            counters.skipped++;
            continue;
        }

        // process rtp/rtcp headers:

        if (!rtp::contains_rtcp(pkt.buf + offset, pkt.cap_len - offset)) {
            counters.skipped++;
            continue;
        }

        auto* rtcp = reinterpret_cast<const rtcp::hdr*>(pkt.buf + offset);

        if ((static_cast<rtcp::pt>(rtcp->pt) != rtcp::pt::rtpfb
            && static_cast<rtcp::pt>(rtcp->pt) != rtcp::pt::rr)
            || (static_cast<rtcp::pt>(rtcp->pt) == rtcp::pt::rtpfb
                && rtcp->fb_fmt() != 15 && rtcp->fb_fmt() != 1)) {
            counters.skipped++;
            continue;
        }


        // based on:
        // https://datatracker.ietf.org/doc/html/draft-holmer-rmcat-transport-wide-cc-extensions-01

        if (static_cast<rtcp::pt>(rtcp->pt) == rtcp::pt::rtpfb && rtcp->fb_fmt() == 1) {

            counters.nack_msgs++;

            auto* nack = reinterpret_cast<const rtcp::nack::hdr*>(pkt.buf + offset);
            offset += rtcp::nack::hdr::LEN;

            for (auto i = 0; i < nack->nack_block_count(); i++) {
                auto* nack_block = reinterpret_cast<const rtcp::nack::nack_block*>(pkt.buf + offset);
                offset += rtcp::nack::nack_block::LEN;

                auto blp_count = 0;

                for (auto j = 0; j < 16; j++) {
                    if (ntohs(nack_block->blp) & (1 << j)) {  // check if j-th bit is set
                        blp_count++;
                    }
                }

                nack_csv_out
                    << pkt.ts.tv_sec << ","
                    << pkt.ts.tv_usec << ","
                    << counters.nack_msgs << ","
                    << net::ipv4::addr_to_str(ntohl(ipv4->src_addr)) << ","
                    << net::ipv4::addr_to_str(ntohl(ipv4->dst_addr)) << ","
                    << ntohs(udp->src_port) << ","
                    << ntohs(udp->dst_port) << ","
                    << ntohs(nack_block->pid) << ","
                    << blp_count << std::endl;

                counters.lines_out++;
            }

        } else if (static_cast<rtcp::pt>(rtcp->pt) == rtcp::pt::rtpfb && rtcp->fb_fmt() == 15) {

            counters.twcc_msgs++;

            auto* twcc = reinterpret_cast<const rtcp::twcc::hdr*>(pkt.buf + offset);
            auto n_pkts = ntohs(twcc->packet_status_count);
            offset += rtcp::twcc::hdr::LEN;

            // Reset vector for each TWCC message
            two_bit_symbols.clear();
            two_bit_symbols.resize(n_pkts);
            
            for (auto pkt_idx = 0; pkt_idx < n_pkts;) {

                auto chunk_type = rtcp::twcc::chunk_type(pkt.buf + offset);

                if (chunk_type == rtcp::twcc::chunk_type::run_length) {

                    auto* chunk = reinterpret_cast<const rtcp::twcc::rl_chunk*>(pkt.buf + offset);

                    for (auto i = 0; i < chunk->length(); i++) {
                        two_bit_symbols[pkt_idx++] = chunk->symbol();
                    }

                    offset += rtcp::twcc::rl_chunk::LEN;

                } else if (chunk_type == rtcp::twcc::chunk_type::status_vector) {

                    auto* chunk = reinterpret_cast<const rtcp::twcc::sv_chunk*>(pkt.buf + offset);

                    if (chunk->symbol_size() == rtcp::twcc::symbol_size::one_bit) {
                        std::cerr << "error: one-bit symbol vector parsing not implemented: "
                                  << counters.pkts_in << std::endl;
                        exit(1);

                    } else if (chunk->symbol_size() == rtcp::twcc::symbol_size::two_bits) {

                        for (auto i = 12; i >= 0; i -= 2) {
                            two_bit_symbols[pkt_idx++] = static_cast<rtcp::twcc::two_bit_status_symbol>(
                                chunk->symbol_list() >> i & 0b11);
                        }

                    } else {
                        std::cerr << "error: unknown symbol size: " << counters.pkts_in << std::endl;
                        exit(1);
                    }

                    offset += rtcp::twcc::sv_chunk::LEN;

                } else {
                    std::cerr << "error: unknown chunk type: " << counters.pkts_in << std::endl;
                    exit(1);
                }
            }

            double rx_time = twcc->ref_time() * 64;
            unsigned seq = ntohs(twcc->base_seq);
            bool received = false;

            for (auto i = 0; i < n_pkts; i++) {

                if (two_bit_symbols[i] == rtcp::twcc::two_bit_status_symbol::received_small_delta) {
                    auto* recv_delta = reinterpret_cast<const rtcp::twcc::small_delta*>(pkt.buf + offset);
                    received = true;
                    rx_time += static_cast<double>(recv_delta->delta) * 0.25;
                    offset += rtcp::twcc::small_delta::LEN;
                } else if (two_bit_symbols[i] == rtcp::twcc::two_bit_status_symbol::received_large_delta) {
                    auto* recv_delta = reinterpret_cast<const rtcp::twcc::large_delta*>(pkt.buf + offset);
                    received = true;
                    rx_time += static_cast<double>(ntohs(recv_delta->delta)) * 0.25;
                    offset += rtcp::twcc::large_delta::LEN;
                } else if (two_bit_symbols[i] == rtcp::twcc::two_bit_status_symbol::not_received) {
                    received = false;
                }

                twcc_csv_out
                    << pkt.ts.tv_sec << ","
                    << pkt.ts.tv_usec << ","
                    << net::ipv4::addr_to_str(ntohl(ipv4->src_addr)) << ","
                    << net::ipv4::addr_to_str(ntohl(ipv4->dst_addr)) << ","
                    << ntohs(udp->src_port) << ","
                    << ntohs(udp->dst_port) << ","
                    << ntohl(twcc->sender_ssrc) << ","
                    << ntohl(twcc->media_ssrc) << ","
                    << ntohs(twcc->feedback_packet_count()) << ","
                    << seq++ << ","
                    << (received ? "true" : "false") << ","
                    << std::fixed << std::setprecision(2);

                if (received) {
                    twcc_csv_out << rx_time;
                } else {
                    twcc_csv_out << "NA";
                }

                twcc_csv_out << std::endl;

                counters.lines_out++;
            }

        } else if (static_cast<rtcp::pt>(rtcp->pt) == rtcp::pt::rr) {

            for (auto i = 0; i < rtcp->recep_rep_count(); i++) {

                auto rr_offset = offset + rtcp::hdr::LEN + i * rtcp::rr::LEN;
                auto* rr = reinterpret_cast<const rtcp::rr*>(pkt.buf + rr_offset);

                rr_csv_out
                    << pkt.ts.tv_sec << ","
                    << pkt.ts.tv_usec << ","
                    << net::ipv4::addr_to_str(ntohl(ipv4->src_addr)) << ","
                    << net::ipv4::addr_to_str(ntohl(ipv4->dst_addr)) << ","
                    << ntohs(udp->src_port) << ","
                    << ntohs(udp->dst_port) << ","
                    << ntohl(rtcp->sender_ssrc) << ","
                    << ntohl(rr->ssrc) << ","
                    << ntohl(rr->jitter) << ","
                    << rr->frac_lost() << ","
                    << rr->cum_lost() << std::endl;
            }

            counters.rr_msgs++;
        }
    }

    twcc_csv_out.close();
    nack_csv_out.close();
    rr_csv_out.close();

    std::cout << " - pkts in: " << counters.pkts_in << std::endl;
    std::cout << " - lines out: " << counters.lines_out << std::endl;
    std::cout << " - twcc msgs: " << counters.twcc_msgs << std::endl;
    std::cout << " - nack msgs: " << counters.nack_msgs << std::endl;
    std::cout << " - rr msgs: " << counters.rr_msgs << std::endl;
    std::cout << " - skipped: " << counters.skipped << std::endl;

    return 0;
}