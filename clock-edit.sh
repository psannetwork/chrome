#!/bin/bash

CPUFREQ_PATH="/sys/devices/system/cpu/cpu0/cpufreq"

get_freq() {
    cat "$CPUFREQ_PATH/$1"
}

set_freq() {
    local freq_khz=$1
    echo "$freq_khz" | sudo tee "$CPUFREQ_PATH/scaling_min_freq" > /dev/null
    echo "$freq_khz" | sudo tee "$CPUFREQ_PATH/scaling_max_freq" > /dev/null
}

reset_to_default() {
    local default_min=$(get_freq "cpuinfo_min_freq")
    local default_max=$(get_freq "cpuinfo_max_freq")
    echo "🔄 デフォルト値にリセット中..."
    echo "$default_min" | sudo tee "$CPUFREQ_PATH/scaling_min_freq" > /dev/null
    echo "$default_max" | sudo tee "$CPUFREQ_PATH/scaling_max_freq" > /dev/null
    echo "✅ デフォルトに戻しました: $((default_min / 1000)) MHz ～ $((default_max / 1000)) MHz"
}

# 現在の状態を表示
current=$(get_freq "scaling_cur_freq")
min=$(get_freq "scaling_min_freq")
max=$(get_freq "scaling_max_freq")

echo "===== 現在のCPUクロック情報 ====="
echo "現在の周波数: $((current / 1000)) MHz"
echo "最小周波数  : $((min / 1000)) MHz"
echo "最大周波数  : $((max / 1000)) MHz"
echo "================================="
echo ""
echo "周波数を MHz 単位で入力してください（例：1800）"
echo "または 'reset' と入力してデフォルトに戻します。"
echo ""

read -p "入力: " user_input

# リセットモード
if [[ "$user_input" == "reset" ]]; then
    reset_to_default
    exit 0
fi

# 数値チェック
if ! [[ "$user_input" =~ ^[0-9]+$ ]]; then
    echo "⚠️ 数字または 'reset' を入力してください。"
    exit 1
fi

# MHz → kHz に変換
new_freq=$((user_input * 1000))

# 範囲チェック
if [ "$new_freq" -lt "$min" ] || [ "$new_freq" -gt "$max" ]; then
    echo "⚠️ 入力値は最小($((min/1000)) MHz)〜最大($((max/1000)) MHz)の範囲で指定してください。"
    exit 1
fi

# 設定反映
set_freq "$new_freq"
echo "✅ 周波数を $user_input MHz に設定しました！"
