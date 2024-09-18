#!/bin/bash

DEFAULT_NUM_ITERATIONS=1000000
DEFAULT_NUM_REPEATS=5

NUM_ITERATIONS=${1:-$DEFAULT_NUM_ITERATIONS}
NUM_REPEATS=${2:-$DEFAULT_NUM_REPEATS}

OUTPUT_FILE="benchmark_results.txt"

echo "ベンチマーク結果 - $(date)" | tee "$OUTPUT_FILE"

total_time=0
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "ベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"

    start_time=$(date +%s%N)
    sum=0
    for ((j=1; j<=NUM_ITERATIONS; j++))
    do
        sum=$((sum + j))
    done
    end_time=$(date +%s%N)
    integer_time=$(( (end_time - start_time) / 1000000 ))
    echo "整数計算の時間: ${integer_time}ms" | tee -a "$OUTPUT_FILE"

    start_time=$(date +%s%N)
    sum=0
    for ((j=1; j<=NUM_ITERATIONS; j++))
    do
        sum=$(echo "$sum + $j" | bc)
    done
    end_time=$(date +%s%N)
    float_time=$(( (end_time - start_time) / 1000000 ))
    echo "浮動小数点計算の時間: ${float_time}ms" | tee -a "$OUTPUT_FILE"

    total_time=$((total_time + integer_time + float_time))
done

average_time=$((total_time / (NUM_REPEATS * 2)))
echo "平均処理時間: ${average_time}ms" | tee -a "$OUTPUT_FILE"

echo "メモリベンチマーク" | tee -a "$OUTPUT_FILE"
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "メモリベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"
    
    start_time=$(date +%s%N)
    dd if=/dev/zero of=/tmp/memory_test bs=1M count=100 oflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    mem_write_time=$(( (end_time - start_time) / 1000000 ))
    echo "メモリ書き込みの時間: ${mem_write_time}ms" | tee -a "$OUTPUT_FILE"

    start_time=$(date +%s%N)
    dd if=/tmp/memory_test of=/dev/null bs=1M count=100 iflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    mem_read_time=$(( (end_time - start_time) / 1000000 ))
    echo "メモリ読み取りの時間: ${mem_read_time}ms" | tee -a "$OUTPUT_FILE"

    rm -f /tmp/memory_test
done

echo "ディスクベンチマーク" | tee -a "$OUTPUT_FILE"
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "ディスクベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"
    
    start_time=$(date +%s%N)
    dd if=/dev/zero of=/tmp/disk_test bs=1M count=100 oflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    disk_write_time=$(( (end_time - start_time) / 1000000 ))
    echo "ディスク書き込みの時間: ${disk_write_time}ms" | tee -a "$OUTPUT_FILE"

    start_time=$(date +%s%N)
    dd if=/tmp/disk_test of=/dev/null bs=1M count=100 iflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    disk_read_time=$(( (end_time - start_time) / 1000000 ))
    echo "ディスク読み取りの時間: ${disk_read_time}ms" | tee -a "$OUTPUT_FILE"

    rm -f /tmp/disk_test
done

echo "結果が ${OUTPUT_FILE} に保存されました。" | tee -a "$OUTPUT_FILE"
