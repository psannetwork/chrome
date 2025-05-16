#!/bin/bash

set -e

IMG="chromeos_16033.58.0_staryu_recovery_stable-channel_mp-v6.bin"
MMC_BASE="/dev/mmcblk0"

# 必須コマンドチェック
for cmd in losetup dd cgpt lsblk; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: '$cmd' がインストールされていません。"
    exit 1
  fi
done

# オプション選択
echo "[?] 書き込みをスキップして、カーネル起動パーティション設定だけ行いますか？ (y/N)"
read -r SKIP_WRITE

# カーネル選択＆cgpt設定だけする場合
if [[ "$SKIP_WRITE" =~ ^[Yy]$ ]]; then
  echo "[+] mmcblk デバイスを確認中..."
  lsblk | grep mmcblk

  echo ""
  read -p "起動に使うカーネルのパーティション番号を入力してください（例: 2）: " KERNEL_INDEX
  if [[ ! "$KERNEL_INDEX" =~ ^[0-9]+$ ]]; then
    echo "Error: 数字以外が入力されました"
    exit 1
  fi

  echo "[+] cgpt add を実行中（-i $KERNEL_INDEX -P 10 -T 5 -S 0）..."
  cgpt add "$MMC_BASE" -i "$KERNEL_INDEX" -P 10 -T 5 -S 0
  echo "[✓] 起動パーティション設定が完了しました。"

  exit 0
fi

# イメージ確認
if [ ! -f "$IMG" ]; then
  echo "Error: イメージが見つかりません: $IMG"
  exit 1
fi

# Loopback セットアップ
echo "[+] Loopback セットアップ中..."
LOOP_DEV=$(losetup --show -fP "$IMG")
echo "[+] 割り当て完了: $LOOP_DEV"

PART3="${LOOP_DEV}p3"
PART4="${LOOP_DEV}p4"

if [ ! -b "$PART3" ] || [ ! -b "$PART4" ]; then
  echo "Error: 必要なパーティションが見つかりません ($PART3, $PART4)"
  losetup -d "$LOOP_DEV"
  exit 1
fi

# dd 書き込み
echo "[+] 書き込み開始（dd）... 超重要：この操作は元に戻せません"
echo ">>> ${PART3} → ${MMC_BASE}p5"
dd if="$PART3" of="${MMC_BASE}p5" bs=4M status=progress conv=fsync

echo ">>> ${PART4} → ${MMC_BASE}p4"
dd if="$PART4" of="${MMC_BASE}p4" bs=4M status=progress conv=fsync

# カーネル選択
echo ""
lsblk | grep mmcblk
echo ""
read -p "起動に使うカーネルのパーティション番号を入力してください（例: 2）: " KERNEL_INDEX
if [[ ! "$KERNEL_INDEX" =~ ^[0-9]+$ ]]; then
  echo "Error: 数字以外が入力されました"
  losetup -d "$LOOP_DEV"
  exit 1
fi

# cgpt
echo "[+] cgpt add を実行中（-i $KERNEL_INDEX -P 10 -T 5 -S 0）..."
cgpt add "$MMC_BASE" -i "$KERNEL_INDEX" -P 10 -T 5 -S 0

# 後片付け
echo "[+] Loopback デバイス解除中..."
losetup -d "$LOOP_DEV"

echo "[✓] すべて完了しました。再起動すれば選択したパーティションから起動します。"
