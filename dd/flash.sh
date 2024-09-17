#!/bin/bash

# 起動しているOSのデバイスを特定
current_os_device=$(lsblk -no pkname $(mount | grep "on / " | awk '{print $1}') | head -n1)

if [ -z "$current_os_device" ]; then
    echo "Failed to identify the current OS device."
    exit 1
fi

# 使用するデバイスをリストアップ（loopやパーティションを除外）
echo "Available block devices (excluding loop devices and partitions):"
devices=($(lsblk -dn -o NAME,TYPE | grep "disk" | awk '{print $1}'))
device_info=($(lsblk -dn -o NAME,SIZE,MODEL | grep "disk"))

# デバイスがない場合のエラーチェック
if [ ${#devices[@]} -eq 0 ]; then
    echo "No valid devices found."
    exit 1
fi

# デバイスの情報を番号付きで表示
for i in "${!devices[@]}"; do
    echo "$((i+1))) ${devices[$i]} $(lsblk -dn -o SIZE,MODEL "/dev/${devices[$i]}")"
done

# 入力プロンプト
read -p "Enter the number corresponding to the device you want to write the OS to (e.g., 1): " choice

# 入力が有効か確認
if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#devices[@]}" ]; then
    target_device=${devices[$((choice-1))]}
else
    echo "Invalid selection. Exiting."
    exit 1
fi

# 選択されたデバイスが存在するか確認
if [ ! -b "/dev/$target_device" ]; then
    echo "Invalid device: /dev/$target_device"
    exit 1
fi

# 選択されたデバイスのパーティションがマウントされているか確認
mountpoints=$(lsblk -o MOUNTPOINT "/dev/$target_device" | grep -v "MOUNTPOINT" | grep -v "^$")

if [ -n "$mountpoints" ]; then
    echo "The device has mounted partitions:"
    echo "$mountpoints"
    
    # マウントされているパーティションをアンマウント
    for mp in $mountpoints; do
        echo "Unmounting $mp..."
        umount "$mp" || { echo "Failed to unmount $mp"; }
    done
fi

# 現在のOSデバイスがターゲットデバイスと同じ場合は警告
if [ "/dev/$current_os_device" == "/dev/$target_device" ]; then
    echo "Warning: You are about to overwrite the current OS device. Proceed with caution."
fi

# 書き込み先のデバイスが重要なマウントポイントで使用されていないことを確認
for mp in /dev /sys /proc /run; do
    if mountpoint -q "$mp"; then
        echo "Warning: $mp is mounted. Ensure this is not the target device."
    fi
done

# 確認のメッセージ
echo "This will overwrite all data on /dev/$target_device. Are you sure? (y/n)"
read confirmation
if [ "$confirmation" != "y" ]; then
    echo "Operation cancelled."
    exit 1
fi

# データのサイズを取得
size=$(lsblk -b -n -o SIZE "/dev/$current_os_device")

# ddコマンドでOSを指定されたデバイスに書き込む
echo "Writing the current OS to /dev/$target_device..."
dd if="/dev/$current_os_device" of="/dev/$target_device" bs=4M status=progress conv=fsync | \
awk 'BEGIN{OFS=""; print "Progress: [",sprintf("%-50s", ""); printf "] %d%%", 0} 
     {
        if (match($0, /(\d+) bytes/)) {
            progress = int(50 * (RSTART / (size/2)))
            printf("\rProgress: [%-50s] %d%%", substr("##################################################", 1, progress), int(100 * (RSTART / size)))
        }
     }'

# 処理完了
echo "Operation completed. Please verify the written data."
