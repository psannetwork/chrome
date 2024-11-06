#!/bin/bash

# kukui.bin のパス
FILE_PATH="kukui.bin"

# kukui.binが存在するか確認
if [ ! -f "$FILE_PATH" ]; then
    echo "エラー: kukui.bin が見つかりません"
    exit 1
fi

# ループバックデバイスの設定
LOOP_DEVICE=$(sudo losetup --find --show "$FILE_PATH")

# ループバックデバイス作成失敗時のエラーハンドリング
if [ -z "$LOOP_DEVICE" ]; then
    echo "エラー: ループバックデバイスの作成に失敗しました"
    exit 1
fi

# パーティションを認識するためにkpartxを使用
sudo kpartx -av "$LOOP_DEVICE"

# パーティションが認識されたか確認
if [ $? -ne 0 ]; then
    echo "エラー: パーティションの認識に失敗しました"
    exit 1
fi

# 1番目のパーティション (p1) のデバイスを確認
PARTITION_DEVICE="/dev/mapper/$(basename $LOOP_DEVICE)p1"

# p1が存在するか確認
if [ ! -b "$PARTITION_DEVICE" ]; then
    echo "エラー: p1 パーティションが存在しません"
    exit 1
fi

# p1パーティションがマウントできるか確認
sudo mount "$PARTITION_DEVICE" /mnt/kukui

# マウント確認
if [ $? -eq 0 ]; then
    echo "p1パーティションが /mnt/kukui にマウントされました"
else
    echo "エラー: p1 パーティションのマウントに失敗しました"
    exit 1
fi

# スクリプト終了時にクリーンアップするためのトラップ
trap "sudo umount /mnt/kukui; sudo kpartx -d $LOOP_DEVICE" EXIT
