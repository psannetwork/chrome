set -e

# Define variables
ALPINE_ROOT="alpine-root"
ALPINE_TARBALL="alpine-minirootfs-3.22.0-x86_64.tar.gz"
ALPINE_URL="http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/${ALPINE_TARBALL}"

# Function to download a file using wget or curl
download_file() {
    if command -v wget > /dev/null 2>&1; then
        echo "Using wget to download ${ALPINE_TARBALL}..."
        wget "${ALPINE_URL}" -O "${ALPINE_TARBALL}"
    elif command -v curl > /dev/null 2>&1; then
        echo "wget not found, using curl to download ${ALPINE_TARBALL}..."
        curl -L "${ALPINE_URL}" -o "${ALPINE_TARBALL}"
    else
        echo "Error: Neither wget nor curl is installed. Please install one and try again."
        exit 1
    fi
}

# Check if the Alpine environment directory exists
if [ -d "${ALPINE_ROOT}" ]; then
    echo "Alpine environment exists. Entering the environment..."
else
    echo "Alpine environment not found. Creating it now..."

    # Download the Alpine tarball if it hasn't been downloaded
    if [ ! -f "${ALPINE_TARBALL}" ]; then
        download_file
    else
        echo "${ALPINE_TARBALL} already exists. Skipping download."
    fi

    # Create the Alpine root directory and extract the tarball
    mkdir -p "${ALPINE_ROOT}"
    echo "Extracting ${ALPINE_TARBALL} into ${ALPINE_ROOT}..."
    tar -xzf "${ALPINE_TARBALL}" -C "${ALPINE_ROOT}"

    # Configure DNS
    echo "Setting up DNS to 8.8.8.8..."
    echo "nameserver 8.8.8.8" > "${ALPINE_ROOT}/etc/resolv.conf"
fi

# Check if a user is set up
if [ ! -f "${ALPINE_ROOT}/etc/passwd" ] || ! grep -q "^[^:]*:[^:]*:[0-9]\+:" "${ALPINE_ROOT}/etc/passwd"; then
    echo "No user found in Alpine. Creating a new user..."
    read -p "Enter username: " ALPINE_USER
    read -s -p "Enter password: " ALPINE_PASS
    echo

    # Create user in chroot environment
    mkdir -p "${ALPINE_ROOT}/home/${ALPINE_USER}"
    echo "${ALPINE_USER}:$(echo "${ALPINE_PASS}" | openssl passwd -6 -stdin):1000:1000:User,,,:/home/${ALPINE_USER}:/bin/sh" >> "${ALPINE_ROOT}/etc/passwd"
    echo "${ALPINE_USER}:x:1000:1000::/home/${ALPINE_USER}:/bin/sh" >> "${ALPINE_ROOT}/etc/passwd"
    echo "${ALPINE_USER}:!:19117:0:99999:7:::" >> "${ALPINE_ROOT}/etc/shadow"
    echo "${ALPINE_USER} ALL=(ALL) NOPASSWD: ALL" >> "${ALPINE_ROOT}/etc/sudoers"

    echo "User ${ALPINE_USER} created successfully!"
fi

# Start the Alpine environment using proot
echo "Starting Alpine environment using proot..."
./proot --rootfs="${ALPINE_ROOT}" -w / -b /proc:/proc -b /sys:/sys -b /dev:/dev env PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/sh
