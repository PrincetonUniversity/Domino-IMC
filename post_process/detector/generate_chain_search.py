text_to_feature_idx = {'local_inbound_fps_down': 0, 
                       'remote_inbound_fps_down': 1, 
                       'local_outbound_fps_down': 2, 
                       'remote_outbound_fps_down': 3, 
                       'local_outbound_resolution_down': 4, 
                       'remote_outbound_resolution_down': 5,
                       'local_jitter_buffer_drain': 6,
                       'remote_jitter_buffer_drain': 7,
                       'local_target_bitrate_drop': 8,
                       'remote_target_bitrate_drop': 9,
                       'local_gcc_overuse': 10,
                       'remote_gcc_overuse': 11,
                       'local_pushback_drop': 12,
                       'remote_pushback_drop': 13,
                       'local_congestion_window_full': 14,
                       'remote_congestion_window_full': 15,
                       'local_outstanding_bytes_up': 16,
                       'remote_outstanding_bytes_up': 17,
                       'forward_delay_up': 18,
                       'reverse_delay_up': 19,
                       'rrc_state_change': 20,
                       'ul_tbs_drop': 21,
                       'dl_tbs_drop': 22,
                       'ul_app_bitrate_over_phy_bitrate': 23,
                       'dl_app_bitrate_over_phy_bitrate': 24,
                       'dl_cross_traffic': 25,
                       'ul_cross_traffic': 26,
                       'ul_channel_bad': 27,
                       'dl_channel_bad': 28,
                       'ul_scheduling_delay': 29,
                       'ul_harq_retx': 30,
                       'dl_harq_retx': 31,
                       'ul_rlc_retx': 32,
                       'dl_rlc_retx': 33,
                       'ul_pushback_mismatch_target_bitrate': 34,
                       'dl_pushback_mismatch_target_bitrate': 35}
causal_idx = 1

def read_chains(filename):
    """Read and reverse logical chains from file."""
    with open(filename, 'r') as f:
        lines = f.readlines()
    chains = [list(reversed(line.strip().split(' --> '))) for line in lines if line.strip()]
    return chains

def build_tree(chains):
    """Construct decision tree from chains of expressions."""
    tree = {}
    for chain in chains:
        current = tree
        for expr in chain:
            current = current.setdefault(expr.strip(), {})
    return tree

def expr_to_condition(expr):
    """Convert 'A or B' to 'context.get("A") or context.get("B")'."""
    expr = expr.replace(" and ", "&&").replace(" or ", "||")
    tokens = expr.split()
    new_tokens = []
    for token in tokens:
        if token == '&&':
            new_tokens.append('and')
        elif token == '||':
            new_tokens.append('or')
        else:
            new_tokens.append(f"features[{text_to_feature_idx[token]}] == 1")
    return ' '.join(new_tokens)

def generate_code(tree, indent=1):
    """Recursively generate Python code from logic tree."""
    global causal_idx
    last_feature = -1
    code_lines = []
    for expr, subtree in tree.items():
        condition = expr_to_condition(expr)
        code_lines.append('  ' * indent + f"if ({condition}):")
        last_features = expr.split()
        if (indent == 1):
            for feature in last_features:
                code_lines.append('  ' * (indent + 1) + "consequences.add(" \
                    + str(text_to_feature_idx[feature]) + ") # record consequence")
        if subtree:
            code_lines.extend(generate_code(subtree, indent + 1))                
        else:
            code_lines.append('  ' * (indent + 1) + "chains.append(" + \
                str(causal_idx) + ") # Causal chain " + str(causal_idx))
            for feature in last_features:
                code_lines.append('  ' * (indent + 1) + "causes.add(" \
                    + str(text_to_feature_idx[feature]) + ") # record cause")
            causal_idx = causal_idx + 1
            
        # if (indent == 1):
        #     # code_lines.append('  ' * (indent + 1) + "return 0 # unknown cause" )
        #     code_lines.append('  ' * (indent + 1) + '# unknown cause"')
    return code_lines

# to improve the unknown cause when there is an event
def write_function_to_file(tree, filename="decision_tree_generated.py", func_name="backward_trace"):
    with open(filename, 'w+') as f:
        f.write(f"def {func_name}(features):\n")
        f.write(f"  chains = []\n")
        f.write(f"  causes = set()\n")
        f.write(f"  consequences = set()\n")
        
        code_lines = generate_code(tree, indent=1)
        for line in code_lines:
            f.write(line + '\n')
        f.write('  return [consequences, causes, chains]')
    print(f"✅ Function written to: {filename}")

def main():
    chains = read_chains("input.txt")  # Your causal chains go here
    tree = build_tree(chains)
    write_function_to_file(tree, filename="generated_chain_search.py")

if __name__ == "__main__":
    main()