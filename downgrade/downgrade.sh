#!/bin/bash

set -e

MMC_BASE="/dev/mmcblk0"

# Check required commands
for cmd in losetup dd cgpt lsblk findmnt curl jq gzip tar; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ Error: '$cmd' is not installed."
    exit 1
  fi
done

# JSON URL
JSON_URL="https://raw.githubusercontent.com/psannetwork/chrome/refs/heads/main/downgrade/staryu.json"

# Download JSON to temporary file
TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON"' EXIT

echo "📥 Downloading JSON data..."
curl -sSL "$JSON_URL" > "$TMP_JSON"
if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to download JSON."
  exit 1
fi

# Function to display version list with colors
display_versions() {
  echo "📋 Available Versions (Newest First):"
  echo "========================================"
  # Create temporary file for version list
  TEMP_LIST=$(mktemp)
  trap 'rm -f "$TEMP_LIST"' EXIT
  
  # Generate version list and save to temp file
  jq -r '.[] | "\(.chrome_version) (\(.platform_version)) - \(.channel) - \(.date)"' "$TMP_JSON" | \
    sort -rV | \
    nl -v0 -w2 -s') ' | \
    sed 's/^/  /' | \
    cat -n > "$TEMP_LIST"
  
  # Display the list
  cat "$TEMP_LIST"
  echo "========================================"
}

# Display versions with header
display_versions

# Get total count of versions
TOTAL_VERSIONS=$(jq length "$TMP_JSON")
echo "Total versions available: $TOTAL_VERSIONS"

# Get user selection
echo ""
read -p "🔢 Enter version number to install (0-$((TOTAL_VERSIONS-1))): " CHOICE

# Validate input
if [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Please enter a valid number."
  exit 1
fi

# Validate range
if [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -ge "$TOTAL_VERSIONS" ]; then
  echo "❌ Error: Invalid selection. Choose between 0 and $((TOTAL_VERSIONS-1))."
  exit 1
fi

# Get selected version details
INDEX=$CHOICE
CHROME_VERSION=$(jq -r ".[$INDEX].chrome_version" "$TMP_JSON")
PLATFORM_VERSION=$(jq -r ".[$INDEX].platform_version" "$TMP_JSON")
CHANNEL=$(jq -r ".[$INDEX].channel" "$TMP_JSON")
DOWNLOAD_URL=$(jq -r ".[$INDEX].download_url" "$TMP_JSON")
FILENAME=$(jq -r ".[$INDEX].filename" "$TMP_JSON")
DATE=$(jq -r ".[$INDEX].date" "$TMP_JSON")

echo ""
echo "✅ Selected Version Details:"
echo "  Chrome Version: $CHROME_VERSION"
echo "  Platform Version: $PLATFORM_VERSION"
echo "  Channel: $CHANNEL"
echo "  Date: $DATE"
echo "  Download URL: $DOWNLOAD_URL"
echo ""

# Download destination
DOWNLOAD_DIR="/tmp/chromeos_recovery"
mkdir -p "$DOWNLOAD_DIR"
IMG="$DOWNLOAD_DIR/$FILENAME"

# Check if download directory exists and create if needed
if [ ! -d "$DOWNLOAD_DIR" ]; then
  echo "📁 Creating download directory: $DOWNLOAD_DIR"
  mkdir -p "$DOWNLOAD_DIR"
fi

# Verify download directory is writable
if [ ! -w "$DOWNLOAD_DIR" ]; then
  echo "❌ Error: Download directory $DOWNLOAD_DIR is not writable."
  exit 1
fi

# Download image
echo "📥 Downloading image..."
if ! curl -L -o "$IMG" "$DOWNLOAD_URL"; then
  echo "❌ Error: Failed to download image."
  exit 1
fi

echo "✅ Image downloaded successfully to: $IMG"

# Skip write option
echo ""
read -p "🔄 Skip writing and only configure boot partition? (y/N): " SKIP_WRITE

# Kernel-only mode
if [[ "$SKIP_WRITE" =~ ^[Yy]$ ]]; then
  echo ""
  echo "🔍 Checking mmcblk devices..."
  lsblk | grep mmcblk

  echo ""
  read -p "🔧 Enter kernel partition number (e.g., 2): " KERNEL_INDEX
  if [[ ! "$KERNEL_INDEX" =~ ^[0-9]+$ ]]; then
    echo "❌ Error: Invalid input. Please enter a number."
    exit 1
  fi

  # Root partition warning
  ROOT_MOUNT=$(findmnt -n --target / | awk '{print $1}')
  KERNEL_PART="${MMC_BASE}p${KERNEL_INDEX}"

  if [[ "$KERNEL_PART" == "$ROOT_MOUNT" ]]; then
    echo ""
    echo "⚠️  WARNING: Selected kernel partition $KERNEL_PART is currently root partition!"
    echo "    Booting from this partition may cause system instability."
    read -p "    Continue anyway? (y/N): " CONFIRM_KERNEL
    if [[ ! "$CONFIRM_KERNEL" =~ ^[Yy]$ ]]; then
      echo "🛑 Configuration cancelled."
      exit 1
    fi
  fi

  echo ""
  echo "⚙️  Configuring boot partition..."
  cgpt add "$MMC_BASE" -i "$KERNEL_INDEX" -P 10 -T 5 -S 0
  echo "✅ Boot partition configuration completed!"
  exit 0
fi

# Check if image is a zip file and extract it
echo "🔍 Checking image type..."
if [[ "$FILENAME" == *.zip ]]; then
  echo "📦 Detected ZIP file, extracting..."
  # Create temporary directory for extraction
  EXTRACT_DIR=$(mktemp -d)
  trap 'rm -rf "$EXTRACT_DIR"' EXIT
  
  # Extract the zip file using tar (works on Chromebook)
  if tar -xf "$IMG" -C "$EXTRACT_DIR"; then
    # Find the .bin file inside
    BIN_FILE=$(find "$EXTRACT_DIR" -name "*.bin" -type f | head -1)
    if [[ -n "$BIN_FILE" ]]; then
      echo "✅ Found binary file: $BIN_FILE"
      IMG="$BIN_FILE"
    else
      echo "❌ Error: No .bin file found in ZIP archive."
      exit 1
    fi
  else
    echo "❌ Error: Failed to extract ZIP file."
    exit 1
  fi
fi

# Loopback setup
echo ""
echo "💾 Setting up loopback device..."
LOOP_DEV=$(losetup --show -fP "$IMG")
echo "✅ Assigned: $LOOP_DEV"

PART3="${LOOP_DEV}p3"
PART4="${LOOP_DEV}p4"

if [ ! -b "$PART3" ] || [ ! -b "$PART4" ]; then
  echo "❌ Error: Required partitions not found ($PART3, $PART4)"
  losetup -d "$LOOP_DEV"
  exit 1
fi

# Target partition selection
echo ""
echo "📁 Select target partition for root filesystem:"
echo "  3) p3 (Primary root)"
echo "  5) p5 (Alternative root)"
read -p "Enter 3 or 5: " TARGET_P3

if [[ "$TARGET_P3" != "3" && "$TARGET_P3" != "5" ]]; then
  echo "❌ Error: Invalid partition number. Please enter 3 or 5."
  losetup -d "$LOOP_DEV"
  exit 1
fi

TARGET_P3_DEV="${MMC_BASE}p${TARGET_P3}"

# Root partition warning
ROOT_MOUNT=$(findmnt -n --target / | awk '{print $1}')
if [[ "$TARGET_P3_DEV" == "$ROOT_MOUNT" ]]; then
  echo ""
  echo "⚠️  WARNING: Selected partition $TARGET_P3_DEV is currently mounted as root (/)!"
  echo "    Writing to this partition may corrupt your current system."
  read -p "    Continue anyway? (y/N): " CONFIRM_OVERWRITE
  if [[ ! "$CONFIRM_OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "🛑 Write operation cancelled."
    losetup -d "$LOOP_DEV"
    exit 1
  fi
fi

# Write operation with progress bar
echo ""
echo "💾 Writing to disk..."
echo ">>> ${PART3} → ${TARGET_P3_DEV}"
echo "Progress: "
dd if="$PART3" of="$TARGET_P3_DEV" bs=4M status=progress conv=fsync 2>&1 | \
  grep -E "(copied|bytes|MB)" | \
  while read line; do
    echo "  $line"
  done

echo ">>> ${PART4} → ${MMC_BASE}p4"
echo "Progress: "
dd if="$PART4" of="${MMC_BASE}p4" bs=4M status=progress conv=fsync 2>&1 | \
  grep -E "(copied|bytes|MB)" | \
  while read line; do
    echo "  $line"
  done

# Kernel partition selection
echo ""
echo "🔍 Checking mmcblk devices..."
lsblk | grep mmcblk
echo ""
read -p "🔧 Enter kernel partition number (e.g., 2): " KERNEL_INDEX
if [[ ! "$KERNEL_INDEX" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Invalid input. Please enter a number."
  losetup -d "$LOOP_DEV"
  exit 1
fi

# Kernel partition root warning
KERNEL_PART="${MMC_BASE}p${KERNEL_INDEX}"
if [[ "$KERNEL_PART" == "$ROOT_MOUNT" ]]; then
  echo ""
  echo "⚠️  WARNING: Selected kernel partition $KERNEL_PART is currently root partition!"
  echo "    Booting from this partition may cause system instability."
  read -p "    Continue anyway? (y/N): " CONFIRM_KERNEL
  if [[ ! "$CONFIRM_KERNEL" =~ ^[Yy]$ ]]; then
    echo "🛑 Configuration cancelled."
    losetup -d "$LOOP_DEV"
    exit 1
  fi
fi

# cgpt configuration
echo ""
echo "⚙️  Configuring boot partition..."
cgpt add "$MMC_BASE" -i "$KERNEL_INDEX" -P 10 -T 5 -S 0
echo "✅ Boot partition configuration completed!"

# Cleanup
echo ""
echo "🧹 Cleaning up..."
losetup -d "$LOOP_DEV"
echo "✅ Cleanup completed!"

echo ""
echo "🎉 Installation complete!"
echo "💡 Reboot to boot from selected partition."
echo "   You can verify the new boot partition with:"
echo "   sudo cgpt show /dev/mmcblk0"
