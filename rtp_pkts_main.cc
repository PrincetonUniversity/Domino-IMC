
#include <iostream>
#include <cxxopts/cxxopts.h>
#include <fstream>

#include "src/av1.h"
#include "src/net.h"
#include "src/rtp.h"
#include "src/pcap_file_reader.h"

struct config {
    std::string input_file_path;
    std::string output_file_path;
    unsigned twcc_rtp_ext_id = 3;
    unsigned abs_send_time_rtp_ext_id = 2;
    unsigned av1_dd_rtp_ext_id = 12;
};

void print_help(cxxopts::Options& opts, int exit_code = 0) {

    std::ostream& os = (exit_code ? std::cerr : std::cout);
    os << opts.help({""}) << std::endl;
    exit(exit_code);
}

cxxopts::Options set_options() {

    cxxopts::Options opts("rtp_pkts", "WebRTC RTP Packet Printer");

    opts.add_options()
        ("i,in", "input file", cxxopts::value<std::string>(), "IN.pcap")
        ("o,out", "output file", cxxopts::value<std::string>(), "OUT.csv")
        ("t,twcc-ext", "transport-cc rtp extension id", cxxopts::value<unsigned>(), "ID")
        ("s,abs-send-time-ext", "absolute send time rtp extension id", cxxopts::value<unsigned>(), "ID")
        ("a,av1-ext", "transport-cc rtp extension id", cxxopts::value<unsigned>(), "ID")
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

    if (parsed.count("t")) {
        config.twcc_rtp_ext_id = parsed["t"].as<unsigned>();
    }

    if (parsed.count("s")) {
        config.abs_send_time_rtp_ext_id = parsed["s"].as<unsigned>();
    }

    if (parsed.count("a")) {
        config.av1_dd_rtp_ext_id = parsed["a"].as<unsigned>();
    }

    if (parsed.count("h"))
        print_help(opts);

    return config;
}

int main(int argc, char** argv) {

    auto config = parse_options(set_options(), argc, argv);

    pcap_pkt pkt;
    pcap_file_reader pcap_in(config.input_file_path);

    if (pcap_in.datalink_type() != pcap_link_type::eth
        && pcap_in.datalink_type() != pcap_link_type::linux_sll
        && pcap_in.datalink_type() != pcap_link_type::null) {
        std::cerr << "error: only ethernet supported right now, exiting." << std::endl;
        exit(1);
    }

    std::ofstream csv_out(config.output_file_path);

    unsigned long lines_in = 0, lines_out = 0, skipped = 0;

    csv_out << "ts_s,ts_us,encap,ip_src,ip_dst,ip_ttl,udp_src,udp_dst,gtp_ip_src,gtp_ip_dst,"
            << "gtp_ip_ttl,gtp_udp_src,gtp_udp_dst,rtp_tw_seq,rtp_abs_send,rtp_ssrc,rtp_pt,rtp_seq,"
            << "rtp_ts,frame_len,media_len,av1_frame_number,av1_template_id" << std::endl;

    while (pcap_in.next(pkt)) {

        lines_in++;

        std::string encap = "udp";

        net::ipv4::hdr* ipv4     = nullptr;
        net::ipv4::hdr* ipv4_gtp = nullptr;
        net::udp::hdr* udp       = nullptr;
        net::udp::hdr* udp_gtp   = nullptr;

        unsigned offset = 0;

        // process ether header:

        if (pcap_in.datalink_type() == pcap_link_type::eth) {

            const auto* eth = reinterpret_cast<const net::eth::hdr*>(pkt.buf);

            if (static_cast<net::eth::type>(ntohs(eth->ether_type)) != net::eth::type::ipv4) {
                skipped++;
                continue;
            }

            offset += net::eth::HDR_LEN;

        } else if (pcap_in.datalink_type() == pcap_link_type::linux_sll) {
            // add length of Linux self-cooked link layer header
            // https://www.tcpdump.org/linktypes/LINKTYPE_LINUX_SLL.html
            // TODO: should check if type is IPv4
            offset += 16;
        } else if (pcap_in.datalink_type() == pcap_link_type::null) {
            // add length of BSD loopback header
            // https://www.tcpdump.org/linktypes/LINKTYPE_NULL.html
            offset += 4;
        }

        // process ip header:

        ipv4 = (net::ipv4::hdr *) (pkt.buf + offset);

        if ((net::ipv4::proto) ipv4->next_proto_id != net::ipv4::proto::udp) {
            skipped++;
            continue;
        }

        offset += ipv4->ihl_bytes();

        // process udp header

        udp = (net::udp::hdr*) (pkt.buf + offset);

        offset += net::udp::HDR_LEN;

        if (ntohs(udp->src_port) == 2152 || ntohs(udp->dst_port) == 2152) {

            encap = "gtp";

            // skip over gtp header:

            offset += 8;

            // process ip-in-gtp header:

            ipv4_gtp = (net::ipv4::hdr*) (pkt.buf + offset);

            if ((net::ipv4::proto) ipv4_gtp->next_proto_id != net::ipv4::proto::udp) {
                skipped++;
                continue;
            }

            offset += ipv4_gtp->ihl_bytes();

            // process udp-in-gtp header:

            udp_gtp = (net::udp::hdr*) (pkt.buf + offset);

            offset += net::udp::HDR_LEN;
        }

        if (rtp::contains_rtp(pkt.buf + offset, pkt.frame_len - offset)) {

            const auto* rtp = reinterpret_cast<const rtp::hdr*>(pkt.buf + offset);

            auto tw_seq = rtp::get_transport_cc_seq(rtp, config.twcc_rtp_ext_id);
            auto abs_send_time = rtp::get_abs_send_time_ms(rtp, config.abs_send_time_rtp_ext_id);

            // parse av1 dependency descriptor mandatory fields:

            auto av1_ext = rtp::get_ext(rtp, config.av1_dd_rtp_ext_id);
            std::optional<std::uint16_t> av1_frame_number;
            std::optional<std::uint8_t> av1_template_id;

            if (av1_ext && av1_ext->len >= 3) {

                av1::DependencyDescriptor av1{av1_ext->data, av1_ext->len};

                av1_frame_number = av1.mandatoryFields().frameNumber();
                av1_template_id  = av1.mandatoryFields().templateId();

                /*
                std::cout << "SwitchAgent: _handleAV1: av1_dd: "
                          << (av1.mandatoryFields().startOfFrame() ? "start, " : "")
                          << (av1.mandatoryFields().endOfFrame() ? "end, " : "")
                          << "tpl_id=" << av1.mandatoryFields().templateId()
                          << ", frame_num=" << av1.mandatoryFields().frameNumber()
                          << std::endl;
                */


                if (av1.template_dependency_structure_present_flag()) {

                    std::stringstream ss;

                    std::cout << " - av1_dd: "
                              << (av1.mandatoryFields().startOfFrame() ? "start, " : "")
                              << (av1.mandatoryFields().endOfFrame() ? "end, " : "")
                              << "tpl_id=" << av1.mandatoryFields().templateId()
                              << ", frame_num=" << av1.mandatoryFields().frameNumber()
                              << std::endl;

                    for (const auto& [id, tpl]: av1.templates()) {
                        ss << "   - id=" << id << ", spatial_layer_id=" << tpl.spatial_layer_id
                           << ", temporal_layer_id=" << tpl.temporal_layer_id << ", dtis=[ ";
                        for (const auto& dti: tpl.dtis) {
                            ss << av1::dtiString[dti] << " ";
                        }
                        ss << "]" << std::endl;
                    }

                    std::cout << ss.str();
                }
            }






//            std::optional<std::uint16_t> av1_frame_number;
//            std::optional<std::uint8_t> av1_template_id;
            /*
            if (av1_ext && av1_ext->len >= 3) {
                av1_frame_number = ((av1_ext->data[1] & 0xff) << 8)
                                 | ((av1_ext->data[2] & 0xff) << 0);
                av1_template_id = av1_ext->data[0] & 0b00111111;
            }
            */

            auto ext_len = rtp::total_ext_len(rtp);
            auto media_len = ntohs(udp->dgram_len) - net::udp::HDR_LEN - rtp::HDR_LEN - 4 - ext_len;

            csv_out
                << pkt.ts.tv_sec << ","
                << pkt.ts.tv_usec << ","
                << encap << ","

                << net::ipv4::addr_to_str(ntohl(ipv4->src_addr)) << ","
                << net::ipv4::addr_to_str(ntohl(ipv4->dst_addr)) << ","
                << (unsigned) ipv4->time_to_live << ","
                << ntohs(udp->src_port) << ","
                << ntohs(udp->dst_port) << ","

                << (ipv4_gtp ? net::ipv4::addr_to_str(ntohl(ipv4_gtp->src_addr)) : "NA") << ","
                << (ipv4_gtp ? net::ipv4::addr_to_str(ntohl(ipv4_gtp->dst_addr)) : "NA") << ","
                << (ipv4_gtp ? std::to_string((unsigned) ipv4_gtp->time_to_live) : "NA") << ","
                << (udp_gtp ? std::to_string(ntohs(udp_gtp->src_port)) : "NA") << ","
                << (udp_gtp ? std::to_string(ntohs(udp_gtp->dst_port)) : "NA") << ","
                << (tw_seq ? std::to_string(*tw_seq) : "NA") << ","
                << (abs_send_time ? std::to_string(*abs_send_time) : "NA") << ","

                << ntohl(rtp->ssrc) << ","
                << rtp->payload_type() << ","
                << ntohs(rtp->seq) << ","
                << ntohl(rtp->ts) << ","
                << pkt.frame_len << ","
                << media_len << ","

                << (av1_frame_number ? std::to_string(*av1_frame_number) : "NA") << ","
                << (av1_template_id ? std::to_string(*av1_template_id) : "NA")
                << std::endl;

            lines_out++;

        } else {
            skipped++;
        }
    }

    std::cout << " - wrote " << lines_out << " lines to " << config.output_file_path << std::endl;
    std::cout << " - skipped " << skipped << " lines" << std::endl;

    pcap_in.close();
    csv_out.close();

    return 0;
}
