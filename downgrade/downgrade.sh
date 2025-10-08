#!/bin/bash

set -e

MMC_BASE="/dev/mmcblk0"

# 必須コマンドチェック
for cmd in losetup dd cgpt lsblk findmnt; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: '$cmd' がインストールされていません。"
    exit 1
  fi
done

# イメージパス取得
read -p "Chromebookリカバリイメージのパスを入力してください: " IMG
if [ ! -f "$IMG" ]; then
  echo "Error: 指定されたイメージが見つかりません: $IMG"
  exit 1
fi

# 書き込みスキップオプション
echo "[?] 書き込みをスキップしてカーネル起動パーティション設定だけ行いますか？ (y/N)"
read -r SKIP_WRITE

# カーネル選択のみモード
if [[ "$SKIP_WRITE" =~ ^[Yy]$ ]]; then
  echo "[+] mmcblkデバイスを確認中..."
  lsblk | grep mmcblk
  
  echo ""
  read -p "起動に使うカーネルのパーティション番号を入力してください（例: 2）: " KERNEL_INDEX
  if [[ ! "$KERNEL_INDEX" =~ ^[0-9]+$ ]]; then
    echo "Error: 数字以外が入力されました"
    exit 1
  fi

  # ルートパーティション警告
  ROOT_MOUNT=$(findmnt -n --target / | awk '{print $1}')
  KERNEL_PART="${MMC_BASE}p${KERNEL_INDEX}"
  
  if [[ "$KERNEL_PART" == "$ROOT_MOUNT" ]]; then
    echo "[!] 警告: 選択されたカーネルパーティション $KERNEL_PART は現在ルートパーティションです。"
    echo "    この設定で起動するとシステムが不安定になる可能性があります。"
    read -p "    続けますか？(y/N): " CONFIRM_KERNEL
    if [[ ! "$CONFIRM_KERNEL" =~ ^[Yy]$ ]]; then
      echo "[-] 設定を中止しました。"
      exit 1
    fi
  fi

  echo "[+] cgpt add を実行中（-i $KERNEL_INDEX -P 10 -T 5 -S 0）..."
  cgpt add "$MMC_BASE" -i "$KERNEL_INDEX" -P 10 -T 5 -S 0
  echo "[✓] 起動パーティション設定が完了しました。"
  exit 0
fi

# Loopbackセットアップ
echo "[+] Loopbackデバイス作成中..."
LOOP_DEV=$(losetup --show -fP "$IMG")
echo "[+] 割り当て完了: $LOOP_DEV"

PART3="${LOOP_DEV}p3"
PART4="${LOOP_DEV}p4"

if [ ! -b "$PART3" ] || [ ! -b "$PART4" ]; then
  echo "Error: 必要なパーティションが見つかりません ($PART3, $PART4)"
  losetup -d "$LOOP_DEV"
  exit 1
fi

# 書き込み先パーティション選択
echo ""
echo "[?] ルートファイルシステム（イメージのp3）をどのパーティションに書き込みますか？"
read -p "3（p3）または5（p5）を入力してください: " TARGET_P3

if [[ "$TARGET_P3" != "3" && "$TARGET_P3" != "5" ]]; then
  echo "Error: 無効なパーティション番号です。3または5を入力してください。"
  losetup -d "$LOOP_DEV"
  exit 1
fi

TARGET_P3_DEV="${MMC_BASE}p${TARGET_P3}"

# ルートパーティション警告
ROOT_MOUNT=$(findmnt -n --target / | awk '{print $1}')
if [[ "$TARGET_P3_DEV" == "$ROOT_MOUNT" ]]; then
  echo "[!] 警告: 選択されたパーティション $TARGET_P3_DEV は現在ルート(/)としてマウントされています。"
  echo "    このパーティションに書き込むと、現在のシステムが破壊される可能性があります。"
  read -p "    続けますか？(y/N): " CONFIRM_OVERWRITE
  if [[ ! "$CONFIRM_OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "[-] 書き込みを中止しました。"
    losetup -d "$LOOP_DEV"
    exit 1
  fi
fi

# 書き込み処理
echo ""
echo "[+] 書き込み開始（dd）... 超重要：この操作は元に戻せません"
echo ">>> ${PART3} → ${TARGET_P3_DEV}"
dd if="$PART3" of="$TARGET_P3_DEV" bs=4M status=progress conv=fsync

echo ">>> ${PART4} → ${MMC_BASE}p4"
dd if="$PART4" of="${MMC_BASE}p4" bs=4M status=progress conv=fsync

# カーネルパーティション選択
echo ""
lsblk | grep mmcblk
echo ""
read -p "起動に使うカーネルのパーティション番号を入力してください（例: 2）: " KERNEL_INDEX
if [[ ! "$KERNEL_INDEX" =~ ^[0-9]+$ ]]; then
  echo "Error: 数字以外が入力されました"
  losetup -d "$LOOP_DEV"
  exit 1
fi

# カーネルパーティションのルート警告
KERNEL_PART="${MMC_BASE}p${KERNEL_INDEX}"
if [[ "$KERNEL_PART" == "$ROOT_MOUNT" ]]; then
  echo "[!] 警告: 選択されたカーネルパーティション $KERNEL_PART は現在ルートパーティションです。"
  echo "    この設定で起動するとシステムが不安定になる可能性があります。"
  read -p "    続けますか？(y/N): " CONFIRM_KERNEL
  if [[ ! "$CONFIRM_KERNEL" =~ ^[Yy]$ ]]; then
    echo "[-] 設定を中止しました。"
    losetup -d "$LOOP_DEV"
    exit 1
  fi
fi

# cgpt設定
echo "[+] cgpt add を実行中（-i $KERNEL_INDEX -P 10 -T 5 -S 0）..."
cgpt add "$MMC_BASE" -i "$KERNEL_INDEX" -P 10 -T 5 -S 0

# 後片付け
echo "[+] Loopbackデバイス解除中..."
losetup -d "$LOOP_DEV"

echo "[✓] すべて完了しました。再起動すれば選択したパーティションから起動します。"
