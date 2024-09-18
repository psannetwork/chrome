#!/bin/bash

DEFAULT_NUM_ITERATIONS=1000000
DEFAULT_NUM_REPEATS=5
DEFAULT_NUM_MEM_REPEATS=10

NUM_ITERATIONS=${1:-$DEFAULT_NUM_ITERATIONS}
NUM_REPEATS=${2:-$DEFAULT_NUM_REPEATS}
NUM_MEM_REPEATS=${3:-$DEFAULT_NUM_MEM_REPEATS}

OUTPUT_FILE="benchmark_results.txt"

clear
echo "ベンチマーク結果 - $(date)" | tee "$OUTPUT_FILE"

calculate_iqr() {
    local values=("$@")
    local length=${#values[@]}
    
    if [ $length -eq 0 ]; then
        echo 0
        return
    fi

    IFS=$'\n' sorted_values=($(sort -n <<<"${values[*]}"))
    q1_index=$((length / 4))
    q3_index=$(((3 * length) / 4))
    
    q1=${sorted_values[$q1_index]}
    q3=${sorted_values[$q3_index]}
    iqr=$((q3 - q1))
    
    echo $iqr
}

remove_outliers() {
    local values=("$@")
    local length=${#values[@]}
    
    if [ $length -lt 4 ]; then
        echo "${values[@]}"
        return
    fi

    IFS=$'\n' sorted_values=($(sort -n <<<"${values[*]}"))
    iqr=$(calculate_iqr "${sorted_values[@]}")
    
    local q1=${sorted_values[$((length / 4))]}
    local q3=${sorted_values[$(((3 * length) / 4))]}
    local lower_bound=$((q1 - 1.5 * iqr))
    local upper_bound=$((q3 + 1.5 * iqr))
    
    filtered_values=()
    for value in "${sorted_values[@]}"; do
        if (( value >= lower_bound && value <= upper_bound )); then
            filtered_values+=("$value")
        fi
    done
    
    echo "${filtered_values[@]}"
}

# 整数計算と浮動小数点演算のベンチマーク
total_time_integer=0
total_time_float=0

read -p "浮動小数点計算を行いますか？ (y/n): " run_float

for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "ベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"

    integer_times=()
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
        integer_times+=($integer_time)
    done
    
    filtered_integer_times=($(remove_outliers "${integer_times[@]}"))
    average_time_integer=$((($(IFS=+; echo "$((${filtered_integer_times[*]}))") / ${#filtered_integer_times[@]})))
    echo "整数計算の時間: ${average_time_integer}ms" | tee -a "$OUTPUT_FILE"
    total_time_integer=$((total_time_integer + average_time_integer))

    if [ "$run_float" == "y" ]; then
        float_times=()
        for ((k=1; k<=5; k++))  # 浮動小数点計算の平均を取るために5回実行
        do
            start_time=$(date +%s%N)
            sum=0
            for ((j=1; j<=NUM_ITERATIONS; j++))
            do
                sum=$(echo "$sum + $j" | bc)
            done
            end_time=$(date +%s%N)
            float_time=$(( (end_time - start_time) / 1000000 ))
            float_times+=($float_time)
        done
        
        filtered_float_times=($(remove_outliers "${float_times[@]}"))
        average_time_float=$((($(IFS=+; echo "$((${filtered_float_times[*]}))") / ${#filtered_float_times[@]})))
        echo "浮動小数点計算の時間: ${average_time_float}ms" | tee -a "$OUTPUT_FILE"
        total_time_float=$((total_time_float + average_time_float))
    else
        float_time=0
    fi
done

average_time_integer=$((total_time_integer / NUM_REPEATS))
average_time_float=$((total_time_float / NUM_REPEATS))
echo "平均整数計算の時間: ${average_time_integer}ms" | tee -a "$OUTPUT_FILE"
echo "平均浮動小数点計算の時間: ${average_time_float}ms" | tee -a "$OUTPUT_FILE"

# メモリの読み書き速度のベンチマーク
echo "メモリベンチマーク" | tee -a "$OUTPUT_FILE"
mem_write_times=()
mem_read_times=()
for ((i=1; i<=NUM_MEM_REPEATS; i++))
do
    echo "メモリベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"
    
    start_time=$(date +%s%N)
    dd if=/dev/zero of=/tmp/memory_test bs=1M count=100 oflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    mem_write_time=$(( (end_time - start_time) / 1000000 ))
    mem_write_times+=($mem_write_time)
    echo "メモリ書き込みの時間: ${mem_write_time}ms" | tee -a "$OUTPUT_FILE"

    start_time=$(date +%s%N)
    dd if=/tmp/memory_test of=/dev/null bs=1M count=100 iflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    mem_read_time=$(( (end_time - start_time) / 1000000 ))
    mem_read_times+=($mem_read_time)
    echo "メモリ読み取りの時間: ${mem_read_time}ms" | tee -a "$OUTPUT_FILE"

    rm -f /tmp/memory_test
done

filtered_mem_write_times=($(remove_outliers "${mem_write_times[@]}"))
filtered_mem_read_times=($(remove_outliers "${mem_read_times[@]}"))
average_mem_write_time=$((($(IFS=+; echo "$((${filtered_mem_write_times[*]}))") / ${#filtered_mem_write_times[@]})))
average_mem_read_time=$((($(IFS=+; echo "$((${filtered_mem_read_times[*]}))") / ${#filtered_mem_read_times[@]})))
echo "平均メモリ書き込みの時間: ${average_mem_write_time}ms" | tee -a "$OUTPUT_FILE"
echo "平均メモリ読み取りの時間: ${average_mem_read_time}ms" | tee -a "$OUTPUT_FILE"

# ディスクの読み書き速度のベンチマーク
echo "ディスクベンチマーク" | tee -a "$OUTPUT_FILE"
disk_write_times=()
disk_read_times=()
for ((i=1; i<=NUM_REPEATS; i++))
do
    echo "ディスクベンチマーク $i 回目の実行" | tee -a "$OUTPUT_FILE"
    
    start_time=$(date +%s%N)
    dd if=/dev/zero of=/tmp/disk_test bs=1M count=100 oflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    disk_write_time=$(( (end_time - start_time) / 1000000 ))
    disk_write_times+=($disk_write_time)
    echo "ディスク書き込みの時間: ${disk_write_time}ms" | tee -a "$OUTPUT_FILE"

    start_time=$(date +%s%N)
    dd if=/tmp/disk_test of=/dev/null bs=1M count=100 iflag=direct 2>/dev/null
    end_time=$(date +%s%N)
    disk_read_time=$(( (end_time - start_time) / 1000000 ))
    disk_read_times+=($disk_read_time)
    echo "ディスク読み取りの時間: ${disk_read_time}ms" | tee -a "$OUTPUT_FILE"

    rm -f /tmp/disk_test
done

filtered_disk_write_times=($(remove_outliers "${disk_write_times[@]}"))
filtered_disk_read_times=($(remove_outliers "${disk_read_times[@]}"))
average_disk_write_time=$((($(IFS=+; echo "$((${filtered_disk_write_times[*]}))") / ${#filtered_disk_write_times[@]})))
average_disk_read_time=$((($(IFS=+; echo "$((${filtered_disk_read_times[*]}))") / ${#filtered_disk_read_times[@]})))
echo "平均ディスク書き込みの時間: ${average_disk_write_time}ms" | tee -a "$OUTPUT_FILE"
echo "平均ディスク読み取りの時間: ${average_disk_read_time}ms" | tee -a "$OUTPUT_FILE"

# 総合得点の算出
integer_score=$((1000000 / (average_time_integer + 1)))  # +1 to avoid division by zero
float_score=$((1000000 / (average_time_float + 1)))
mem_write_score=$((1000000 / (average_mem_write_time + 1)))
mem_read_score=$((1000000 / (average_mem_read_time + 1)))
disk_write_score=$((1000000 / (average_disk_write_time + 1)))
disk_read_score=$((1000000 / (average_disk_read_time + 1)))

average_score=$(((integer_score + float_score + mem_write_score + mem_read_score + disk_write_score + disk_read_score) / 6))

echo "総合スコア: ${average_score}" | tee -a "$OUTPUT_FILE"

echo "結果が ${OUTPUT_FILE} に保存されました。" | tee -a "$OUTPUT_FILE"
