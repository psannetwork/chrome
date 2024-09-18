#!/bin/bash

DEFAULT_NUM_ITERATIONS=1000000
DEFAULT_NUM_REPEATS=5

NUM_ITERATIONS=${1:-$DEFAULT_NUM_ITERATIONS}
NUM_REPEATS=${2:-$DEFAULT_NUM_REPEATS}

OUTPUT_FILE="benchmark_results.txt"

# 画面をクリア
clear

echo "ベンチマーク結果 - $(date)" | tee "$OUTPUT_FILE"

# 整数計算と浮動小数点演算のベンチマーク
total_time_integer=0
total_time_float=0
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "ベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"

    # 整数計算の平均時間
    total_integer_time=0
    for ((k=1; k<=5; k++))  # 整数計算の平均を取るために5回実行
    do
        start_time=$(date +%s%N)
        sum=0
        for ((j=1; j<=NUM_ITERATIONS; j++))
        do
            sum=$((sum + j))
        done
        end_time=$(date +%s%N)
        integer_time=$(( (end_time - start_time) / 1000000 ))
        total_integer_time=$((total_integer_time + integer_time))
    done
    average_time_integer=$((total_integer_time / 5))
    echo "整数計算の時間: ${average_time_integer}ms" | tee -a "$OUTPUT_FILE"
    total_time_integer=$((total_time_integer + average_time_integer))

    # 浮動小数点演算の時間
    start_time=$(date +%s%N)
    sum=0
    for ((j=1; j<=NUM_ITERATIONS; j++))
    do
        sum=$(echo "$sum + $j" | bc)
    done
    end_time=$(date +%s%N)
    float_time=$(( (end_time - start_time) / 1000000 ))
    echo "浮動小数点計算の時間: ${float_time}ms" | tee -a "$OUTPUT_FILE"
    total_time_float=$((total_time_float + float_time))
done

average_time_integer=$((total_time_integer / NUM_REPEATS))
average_time_float=$((total_time_float / NUM_REPEATS))
echo "平均整数計算の時間: ${average_time_integer}ms" | tee -a "$OUTPUT_FILE"
echo "平均浮動小数点計算の時間: ${average_time_float}ms" | tee -a "$OUTPUT_FILE"

# メモリの読み書き速度のベンチマーク
echo "メモリベンチマーク" | tee -a "$OUTPUT_FILE"
total_mem_write_time=0
total_mem_read_time=0
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "メモリベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"
    
    start_time=$(date +%s%N)
    dd if=/dev/zero of=/tmp/memory_test bs=1M count=100 oflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    mem_write_time=$(( (end_time - start_time) / 1000000 ))
    echo "メモリ書き込みの時間: ${mem_write_time}ms" | tee -a "$OUTPUT_FILE"
    total_mem_write_time=$((total_mem_write_time + mem_write_time))

    start_time=$(date +%s%N)
    dd if=/tmp/memory_test of=/dev/null bs=1M count=100 iflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    mem_read_time=$(( (end_time - start_time) / 1000000 ))
    echo "メモリ読み取りの時間: ${mem_read_time}ms" | tee -a "$OUTPUT_FILE"
    total_mem_read_time=$((total_mem_read_time + mem_read_time))

    rm -f /tmp/memory_test
done

average_mem_write_time=$((total_mem_write_time / NUM_REPEATS))
average_mem_read_time=$((total_mem_read_time / NUM_REPEATS))
echo "平均メモリ書き込みの時間: ${average_mem_write_time}ms" | tee -a "$OUTPUT_FILE"
echo "平均メモリ読み取りの時間: ${average_mem_read_time}ms" | tee -a "$OUTPUT_FILE"

# ディスクの読み書き速度のベンチマーク
echo "ディスクベンチマーク" | tee -a "$OUTPUT_FILE"
total_disk_write_time=0
total_disk_read_time=0
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "ディスクベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"
    
    start_time=$(date +%s%N)
    dd if=/dev/zero of=/tmp/disk_test bs=1M count=100 oflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    disk_write_time=$(( (end_time - start_time) / 1000000 ))
    echo "ディスク書き込みの時間: ${disk_write_time}ms" | tee -a "$OUTPUT_FILE"
    total_disk_write_time=$((total_disk_write_time + disk_write_time))

    start_time=$(date +%s%N)
    dd if=/tmp/disk_test of=/dev/null bs=1M count=100 iflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    disk_read_time=$(( (end_time - start_time) / 1000000 ))
    echo "ディスク読み取りの時間: ${disk_read_time}ms" | tee -a "$OUTPUT_FILE"
    total_disk_read_time=$((total_disk_read_time + disk_read_time))

    rm -f /tmp/disk_test
done

average_disk_write_time=$((total_disk_write_time / NUM_REPEATS))
average_disk_read_time=$((total_disk_read_time / NUM_REPEATS))
echo "平均ディスク書き込みの時間: ${average_disk_write_time}ms" | tee -a "$OUTPUT_FILE"
echo "平均ディスク読み取りの時間: ${average_disk_read_time}ms" | tee -a "$OUTPUT_FILE"

# 総合得点の算出
# 各ベンチマークの平均時間を元にスコアを計算
integer_score=$((1000000 / (average_time_integer + 1)))  # +1 to avoid division by zero
float_score=$((1000000 / (average_time_float + 1)))
mem_write_score=$((1000000 / (average_mem_write_time + 1)))
mem_read_score=$((1000000 / (average_mem_read_time + 1)))
disk_write_score=$((1000000 / (average_disk_write_time + 1)))
disk_read_score=$((1000000 / (average_disk_read_time + 1)))

# 平均スコアを算出
average_score=$(((integer_score + float_score + mem_write_score + mem_read_score + disk_write_score + disk_read_score) / 6))

echo "総合スコア: ${average_score}" | tee -a "$OUTPUT_FILE"

echo "結果が ${OUTPUT_FILE} に保存されました。" | tee -a "$OUTPUT_FILE"
