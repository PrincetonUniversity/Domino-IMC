
#include <iostream>
#include <cxxopts/cxxopts.h>
#include <fstream>

#include "src/net.h"
#include "src/pcap_file_reader.h"

struct config {
    std::string input_file_path;
    std::string output_file_path;
};

void print_help(cxxopts::Options& opts, int exit_code = 0) {

    std::ostream& os = (exit_code ? std::cerr : std::cout);
    os << opts.help({""}) << std::endl;
    exit(exit_code);
}

cxxopts::Options set_options() {

    cxxopts::Options opts("icmp_pkts", "ICMP Packet Printer");

    opts.add_options()
        ("i,in", "input file", cxxopts::value<std::string>(), "IN.pcap")
        ("o,out", "output file", cxxopts::value<std::string>(), "OUT.csv")
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

    if (parsed.count("o")) {
        config.output_file_path = parsed["o"].as<std::string>();
    } else {
        print_help(opts, 1);
    }

    if (parsed.count("h"))
        print_help(opts);

    return config;
}

int main(int argc, char** argv) {

    const unsigned GTP_HDR_LEN = 8;
    const unsigned short GTP_UDP_PORT = 2152;

    auto config = parse_options(set_options(), argc, argv);

    pcap_pkt pkt;
    pcap_file_reader pcap_in(config.input_file_path);

    if (pcap_in.datalink_type() != pcap_link_type::eth
        && pcap_in.datalink_type() != pcap_link_type::null) {
        std::cerr << "error: only ethernet supported right now, exiting." << std::endl;
        exit(1);
    }

    std::ofstream csv_out(config.output_file_path);

    struct { unsigned long in = 0, out = 0, skip = 0; } counters;

    csv_out << "ts_s,ts_us,ip_src,ip_dst,ip_ttl,icmp_type,icmp_code,icmp_id,icmp_seq,pkt_size" << std::endl;

    while (pcap_in.next(pkt)) {

        counters.in++;

        unsigned offset = 0;

        // process ether header:

        auto *eth = (net::eth::hdr*) pkt.buf;

        if ((net::eth::type) ntohs(eth->ether_type) != net::eth::type::ipv4) {
            counters.skip++;
            continue;
        }

        offset += net::eth::HDR_LEN;

        // process ip header:

        auto ipv4 = (net::ipv4::hdr*) (pkt.buf + offset);

        if ((net::ipv4::proto) ipv4->next_proto_id != net::ipv4::proto::icmp
            && (net::ipv4::proto) ipv4->next_proto_id != net::ipv4::proto::udp) {

            counters.skip++;
            continue;
        }

        offset += ipv4->ihl_bytes();

        // check if packet is encapsulated in gtp if udp header is present
        if ((net::ipv4::proto) ipv4->next_proto_id == net::ipv4::proto::udp) {

            auto udp = (net::udp::hdr*) (pkt.buf + offset);

            offset += net::udp::HDR_LEN;

            if (ntohs(udp->src_port) == GTP_UDP_PORT && ntohs(udp->dst_port) == GTP_UDP_PORT) {

                offset += GTP_HDR_LEN;

                // process ip-in-gtp header:
                auto ipv4_gtp = (net::ipv4::hdr*) (pkt.buf + offset);

                if ((net::ipv4::proto) ipv4_gtp->next_proto_id != net::ipv4::proto::icmp) {
                    counters.skip++;
                    continue;
                }

                offset += ipv4_gtp->ihl_bytes();
            } else {
                counters.skip++;
                continue;
            }
        }

        // process icmp header:

        auto icmp = (net::icmp::hdr*) (pkt.buf + offset);

        if ((net::icmp::type) icmp->type != net::icmp::type::echo_request
            && (net::icmp::type) icmp->type != net::icmp::type::echo_reply) {

            counters.skip++;
            continue;
        }

        offset += net::icmp::HDR_LEN;

        // process icmp echo:

        auto* icmp_echo = (net::icmp::echo_hdr*) (pkt.buf + offset);

        csv_out << pkt.ts.tv_sec << ","
                << pkt.ts.tv_usec << ","
                << net::ipv4::addr_to_str(ntohl(ipv4->src_addr)) << ","
                << net::ipv4::addr_to_str(ntohl(ipv4->dst_addr)) << ","
                << (unsigned) ipv4->time_to_live << ","
                << (unsigned) icmp->type << ","
                << (unsigned) icmp->code << ","
                << std::hex << std::setw(4) << std::setfill('0') << ntohs(icmp_echo->id) << ","
                << std::dec << ntohs(icmp_echo->seq) << ","
                << std::dec << pkt.frame_len
                << std::endl;

        counters.out++;
    }

    std::cout << " - read " << counters.in << " lines from " << config.input_file_path << std::endl;
    std::cout << " - wrote " << counters.out << " lines to " << config.output_file_path << std::endl;
    std::cout << " - skipped " << counters.skip << " lines" << std::endl;

    pcap_in.close();
    csv_out.close();

    return 0;
}