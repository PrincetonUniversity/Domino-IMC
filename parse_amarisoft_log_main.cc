#include <iostream>
#include <fstream>
#include <string>
#include <regex>
#include <chrono>
#include <sstream>

double seconds_sice(const std::chrono::time_point<std::chrono::high_resolution_clock>& start) {
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end - start;
    return duration.count();
}

std::vector<std::string> tokenize_by_whitespace(const std::string& str) {
    std::vector<std::string> tokens;
    std::istringstream stream(str);
    std::string token;

    while (stream >> token) { // `>>` skips any whitespace
        tokens.push_back(token);
    }

    return tokens;
}

struct layer_count {
    unsigned long ul = 0, dl = 0;
};

struct counts {
    layer_count phy, rlc, pdcp;

    [[nodiscard]] unsigned long total() const {
        return phy.ul + phy.dl + rlc.ul + rlc.dl + pdcp.ul + pdcp.dl;
    }
};

int main() {

    /*
     * PDSCH (Physical Downlink Shared Channel)
     * PUSCH (Physical Uplink Shared Channel)
     * PDCCH (Physical Downlink Control Channel)
     * PUCCH (Physical Uplink Control Channel)
     */

    auto start = std::chrono::high_resolution_clock::now();

    std::regex timestamp_regex(R"(^(\b\d{2}:\d{2}:\d{2}\.\d{3}\b)\s\[(PHY|RLC|PDCP)\]\s(UL|DL)(.*))");

    std::string file_name = "/Users/olli/Desktop/data1027/enb-export.log";
    std::ifstream file(file_name);

    if (!file.is_open()) {
        std::cerr << "Failed to open the file." << std::endl;
        return 1;
    }

    std::string line;
    counts totals;

    while (std::getline(file, line)) {

        auto start_index = line.find_first_not_of({' ', '\t'});
        line = line.substr(start_index);
        std::smatch match;

        if (std::regex_match(line, match, timestamp_regex)) {

            std::string timestamp = match.str(1);
            std::string layer = match.str(2);
            std::string direction = match.str(3);
            std::vector<std::string> tokens = tokenize_by_whitespace(match.str(4));

            if (layer == "PHY") {

                if (direction == "UL") {
                    totals.phy.ul++;

                    for (const auto& token : tokens)
                        std::cout << token << ",";

                    std::cout << std::endl;

                    continue;
                } else if (direction == "DL") {
                    totals.phy.dl++;
                    continue;
                }

            } else if (layer == "RLC") {

                if (direction == "UL") {
                    totals.rlc.ul++;
                    continue;
                } else if (direction == "DL") {
                    totals.rlc.dl++;
                    continue;
                }

            } else if (layer == "PDCP") {

                if (direction == "UL") {
                    totals.pdcp.ul++;
                    continue;
                } else if (direction == "DL") {
                    totals.pdcp.dl++;
                    continue;
                }
            }
        }
    }

    file.close();

    // print totals:
    std::cout << "PHY UL: " << totals.phy.ul << std::endl;
    std::cout << "PHY DL: " << totals.phy.dl << std::endl;
    std::cout << "RLC UL: " << totals.rlc.ul << std::endl;
    std::cout << "RLC DL: " << totals.rlc.dl << std::endl;
    std::cout << "PDCP UL: " << totals.pdcp.ul << std::endl;
    std::cout << "PDCP DL: " << totals.pdcp.dl << std::endl;
    std::cout << "Total: " << totals.total() << std::endl;
    std::cout << "Runtime: " << seconds_sice(start) << "s" << std::endl;

    return 0;
}