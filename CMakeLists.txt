cmake_minimum_required(VERSION 3.26)
project(webrtc_cellular_measurements)

set(CMAKE_CXX_STANDARD 17)

include(cmake/pcap.cmake)
include(cmake/cxxopts.cmake)

add_executable(rtp_pkts rtp_pkts_main.cc
        src/av1.h src/av1.cc
        src/net.h
        src/pcap_file_reader.cc
        src/pcap_file_reader.h
        src/pcap_util.h
        src/rtp.h
        src/util.h)

target_include_directories(rtp_pkts PUBLIC ${PCAP_INCLUDE_DIRS})
target_include_directories(rtp_pkts PUBLIC ext/include)
target_link_libraries(rtp_pkts ${PCAP_LIBRARIES})
set_target_properties(rtp_pkts PROPERTIES LINKER_LANGUAGE CXX)


add_executable(icmp_pkts icmp_pkts_main.cc
        src/net.h
        src/pcap_file_reader.cc
        src/pcap_file_reader.h
        src/pcap_util.h)

target_include_directories(icmp_pkts PUBLIC ${PCAP_INCLUDE_DIRS})
target_include_directories(icmp_pkts PUBLIC ext/include)
target_link_libraries(icmp_pkts ${PCAP_LIBRARIES})
set_target_properties(icmp_pkts PROPERTIES LINKER_LANGUAGE CXX)


add_executable(rtcp_pkts rtcp_pkts_main.cc
        src/net.h
        src/pcap_file_reader.cc
        src/pcap_file_reader.h
        src/pcap_util.h
        src/rtcp.h
        src/rtcp_rr.h
        src/rtcp_twcc.h
        src/rtp.h)

target_include_directories(rtcp_pkts PUBLIC ${PCAP_INCLUDE_DIRS})
target_include_directories(rtcp_pkts PUBLIC ext/include)
target_link_libraries(rtcp_pkts ${PCAP_LIBRARIES})
set_target_properties(rtcp_pkts PROPERTIES LINKER_LANGUAGE CXX)


add_executable(parse_amarisoft_log parse_amarisoft_log_main.cc)

target_include_directories(parse_amarisoft_log PUBLIC ${PCAP_INCLUDE_DIRS})
target_include_directories(parse_amarisoft_log PUBLIC ext/include)
target_link_libraries(parse_amarisoft_log ${PCAP_LIBRARIES})
set_target_properties(parse_amarisoft_log PROPERTIES LINKER_LANGUAGE CXX)
