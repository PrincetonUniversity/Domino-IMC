
#ifndef WEBRTC_CELLULAR_AV1_H
#define WEBRTC_CELLULAR_AV1_H

#include <cstdint>
#include <iostream>
#include <map>
#include <vector>

namespace av1 {

    class DependencyDescriptor {

    public:
        enum class dti : unsigned {
            not_present_indication = 0,
            discardable_indication = 1,
            switch_indication      = 2,
            required_indication    = 3
        };

        struct frame_dependency_template {
            unsigned spatial_layer_id  = 0;
            unsigned temporal_layer_id = 0;
            std::vector<dti> dtis = {};
            std::vector<unsigned> fdiffs = {};
        };

        class MandatoryFields {

        public:
            MandatoryFields() = default;
            explicit MandatoryFields(const unsigned char* buf);
            [[nodiscard]] bool startOfFrame() const;
            [[nodiscard]] bool endOfFrame() const;
            [[nodiscard]] unsigned templateId() const;
            [[nodiscard]] unsigned frameNumber() const;

        private:
            const unsigned char* _buf;
        };

        DependencyDescriptor() = default;
        explicit DependencyDescriptor(const unsigned char* bytes, unsigned len);

        [[nodiscard]] const MandatoryFields& mandatoryFields() const;

        [[nodiscard]] bool template_dependency_structure_present_flag() const;
        [[nodiscard]] bool active_decode_targets_present_flag() const;
        [[nodiscard]] bool custom_dtis_flag() const;
        [[nodiscard]] bool custom_fdiffs_flag() const;
        [[nodiscard]] bool custom_chains_flag() const;

        [[nodiscard]] unsigned dtCnt() const;

        [[nodiscard]] const std::map<unsigned, struct frame_dependency_template>& templates() const;

    private:

        void _parse_bytes();
        unsigned _parse_extended_descriptor_fields(const std::vector<bool>& bits, unsigned total_consumed_bits);
        // unsigned _parse_frame_dependency_definition(const std::vector<bool>& bits, unsigned total_consumed_bits);
        unsigned _parse_template_dependency_structure(const std::vector<bool>& bits, unsigned total_consumed_bits);

        unsigned _parse_template_layers(const std::vector<bool>& bits, unsigned i, unsigned& max_spatial_id);
        unsigned _parse_template_dtis(const std::vector<bool>& bits, unsigned it);
        unsigned _parse_template_fdiffs(const std::vector<bool>& bits, unsigned i);

        unsigned _parse_template_chains(const std::vector<bool>& bits, unsigned i, unsigned& chain_cnt);
        unsigned _parse_decode_target_layers(const std::vector<bool>& bits, unsigned i);
        unsigned _parse_render_resolutions(const std::vector<bool>& bits, unsigned i, const unsigned& max_spatial_id);
        unsigned _parse_frame_chains(const std::vector<bool>& bits, unsigned i, unsigned& chain_cnt);
        unsigned _parse_frame_dependency_definition(const std::vector<bool>& bits, unsigned i);

        [[nodiscard]] static std::vector<bool> _bit_vector_from_bytes(const unsigned char* buf, unsigned len);

        const unsigned char* _buf;
        unsigned _len;

        class MandatoryFields _mandatoryFields;

        bool _template_dependency_structure_present_flag = false;
        bool _active_decode_targets_present_flag = false;
        bool _custom_dtis_flag = false;
        bool _custom_fdiffs_flag = false;
        bool _custom_chains_flag = false;

        unsigned _dt_cnt = 0;
        unsigned _template_cnt = 0;
        unsigned _template_id_offset = 0;
        std::uint32_t _active_decode_targets_bitmask = 0;
        bool _resolutions_present_flag = false;

        std::vector<unsigned> _template_spatial_id = {};
        std::vector<unsigned> _template_temporal_id = {};

        std::vector<std::vector<unsigned>> _template_dti = {};

        std::vector<unsigned> _decode_target_spatial_id = {};
        std::vector<unsigned> _decode_target_temporal_id = {};

        std::vector<unsigned> _max_render_width_minus_one = {};
        std::vector<unsigned> _max_render_height_minus_one = {};

        std::map<unsigned, struct frame_dependency_template> _templates;

        static const unsigned MandatoryFields_LEN = 3;
    };

    static std::map<DependencyDescriptor::dti, std::string> dtiString = {
            {DependencyDescriptor::dti::not_present_indication, "not-present"},
            {DependencyDescriptor::dti::discardable_indication, "discardable"},
            {DependencyDescriptor::dti::switch_indication, "switch"},
            {DependencyDescriptor::dti::required_indication, "required"}
    };
}

#endif
