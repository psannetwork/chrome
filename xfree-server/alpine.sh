set -e

# Define variables
ALPINE_ROOT="alpine-root"
ALPINE_TARBALL="alpine-minirootfs-3.21.3-x86_64.tar.gz"
ALPINE_URL="http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/${ALPINE_TARBALL}"

# Check if the Alpine environment directory exists
if [ -d "${ALPINE_ROOT}" ]; then
    echo "Alpine environment exists. Entering the environment..."
else
    echo "Alpine environment not found. Creating it now..."

    # Download the Alpine tarball if it hasn't been downloaded
    if [ ! -f "${ALPINE_TARBALL}" ]; then
         echo "Downloading ${ALPINE_TARBALL}..."
         wget "${ALPINE_URL}" -O "${ALPINE_TARBALL}"
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

# Start the Alpine environment using proot
echo "Starting Alpine environment using proot..."
# Set working directory to / and initialize PATH for basic commands
./proot --rootfs="${ALPINE_ROOT}" -w / -b /proc:/proc -b /sys:/sys -b /dev:/dev env PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/sh
