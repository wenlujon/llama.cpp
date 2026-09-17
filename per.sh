#MODEL=../models/Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf
#MODEL=../models/Qwen3-235B-A22B-Q4_K_M-00001-of-00005.gguf
MODEL=../models/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf

num_cores=128
numa1_start_core=64

numa_node_count=$(find /sys/devices/system/node -maxdepth 1 -type d -name 'node[0-9]*' | wc -l)
if [ "$numa_node_count" -eq 1 ]; then
    # This build has two migration slots, but this host exposes only physical node 0.
    export GGML_NUMA_NODE_IDS=0,0
elif [ "$numa_node_count" -ne 2 ]; then
    printf 'Unsupported NUMA topology: expected 1 or 2 nodes, found %d\n' \
        "$numa_node_count" >&2
    exit 1
fi

for threads in $(seq 128 2 $num_cores); do
    threads_per_node=$((threads / 2))

    node0_last=$((threads_per_node - 1))
    node1_last=$((numa1_start_core + threads_per_node - 1))

    # 2 threads:   0-0|64-64
    # 4 threads:   0-1|64-65
    # 128 threads: 0-63|64-127
    core_ids="0-${node0_last}|64-${node1_last}"

    printf '\n=== threads=%d, core_ids=%s ===\n' \
        "$threads" "$core_ids"

    GGML_NUMA_CORE_IDS="$core_ids" \
	build/bin/llama-perplexity -m $MODEL -f wikitext-2-raw/wiki.test.raw -t $threads --numa migrate
done
