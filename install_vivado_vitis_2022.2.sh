#!/bin/bash
# =============================================================================
# Vivado / Vitis 2022.2 Installer for ARM Ubuntu 22.04 in Parallels + Rosetta
# Host:  Apple M4 Pro, macOS 26.5.1, Parallels 26.3.3
# Guest: Ubuntu 22.04.5 LTS aarch64
#
# Usage: sudo bash install_vivado_vitis_2022.2.sh <path-to-installer.bin>
# Example:
#   sudo bash install_vivado_vitis_2022.2.sh \
#     ~/Downloads/Xilinx_Unified_2022.2_1014_8888_Lin64.bin
# =============================================================================

set -e

INSTALLER_BIN="$1"
EXTRACT_DIR="/tmp/vivado_extract"
ROSETTA="/media/psf/RosettaLinux/rosetta"
UNAME_SHIM_DIR="/usr/local/bin/vivado_shims"
INSTALL_DIR="/tools/Xilinx"

# -----------------------------------------------------------------------------
# 0. Checks
# -----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Run as root: sudo bash $0 $*"
    exit 1
fi

if [ -z "$INSTALLER_BIN" ]; then
    echo "Usage: sudo bash $0 <path-to-installer.bin>"
    exit 1
fi

if [ ! -f "$INSTALLER_BIN" ]; then
    echo "ERROR: Installer not found: $INSTALLER_BIN"
    exit 1
fi

# Preserve real user's display for GUI under sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$REAL_HOME/.Xauthority}"

echo "=============================================="
echo " Vivado / Vitis 2022.2 Installer"
echo " Guest: Ubuntu 22.04 aarch64"
echo "=============================================="

# -----------------------------------------------------------------------------
# 1. Check Rosetta
# -----------------------------------------------------------------------------
echo ""
echo "[1/6] Checking Rosetta..."
if [ ! -f "$ROSETTA" ]; then
    echo "ERROR: Rosetta not found at $ROSETTA"
    echo "  -> Install Parallels Tools first (Actions -> Install Parallels Tools)"
    echo "  -> Then reboot and re-run this script"
    exit 1
fi
echo "  OK: $ROSETTA"

# -----------------------------------------------------------------------------
# 2. Register Rosetta as binfmt handler
# -----------------------------------------------------------------------------
echo ""
echo "[2/6] Registering Rosetta as x86_64 binfmt handler..."
if [ -f /proc/sys/fs/binfmt_misc/rosetta ]; then
    echo "  Already registered."
else
    echo ':rosetta:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/media/psf/RosettaLinux/rosetta:CF' \
        | tee /proc/sys/fs/binfmt_misc/register > /dev/null
    echo "  Registered."
fi

# Make binfmt_misc registration persistent across reboots
if [ ! -f /etc/systemd/system/rosetta-binfmt.service ]; then
    cat > /etc/systemd/system/rosetta-binfmt.service << 'EOF'
[Unit]
Description=Register Rosetta as x86_64 binfmt handler
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo :rosetta:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/media/psf/RosettaLinux/rosetta:CF > /proc/sys/fs/binfmt_misc/register'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable rosetta-binfmt > /dev/null 2>&1
    echo "  Persistent binfmt service installed."
fi

# -----------------------------------------------------------------------------
# 3. Add amd64 architecture and install x86-64 libraries
# -----------------------------------------------------------------------------
echo ""
echo "[3/6] Installing x86-64 libraries..."

# Add amd64 arch
dpkg --add-architecture amd64

# Fix sources: ports.ubuntu.com doesn't carry amd64 packages
if ! grep -q "archive.ubuntu.com" /etc/apt/sources.list.d/amd64.list 2>/dev/null; then
    cat > /etc/apt/sources.list.d/amd64.list << 'EOF'
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
    # Restrict existing arm64 sources to arm64 only
    sed -i 's/^deb http/deb [arch=arm64] http/' /etc/apt/sources.list
fi

apt-get update -qq

# Core x86-64 runtime libs
apt-get install -y \
    libc6:amd64 \
    libstdc++6:amd64 \
    libgcc-s1:amd64 \
    libpixman-1-0:amd64 \
    libkrb5-3:amd64 \
    libgssapi-krb5-2:amd64 \
    libtinfo5:amd64 \
    libncurses5:amd64 \
    libxext6:amd64 \
    libxrender1:amd64 \
    libxtst6:amd64 \
    libxi6:amd64 \
    libxrandr2:amd64 \
    libxfixes3:amd64 \
    libxcursor1:amd64 \
    libxinerama1:amd64 \
    libx11-6:amd64 \
    libxau6:amd64 \
    libxdmcp6:amd64 \
    libgtk-3-0:amd64 \
    libgdk-pixbuf2.0-0:amd64 \
    libcairo2:amd64 \
    libpango-1.0-0:amd64 \
    libpangocairo-1.0-0:amd64 \
    libatk1.0-0:amd64 \
    libglib2.0-0:amd64 \
    libwebkit2gtk-4.0-37:amd64 \
    fontconfig:amd64 \
    fonts-dejavu-core \
    xfonts-base

echo "  x86-64 libraries installed."

# -----------------------------------------------------------------------------
# 4. Extract installer
# -----------------------------------------------------------------------------
echo ""
echo "[4/6] Extracting installer to $EXTRACT_DIR ..."
rm -rf "$EXTRACT_DIR"
sh "$INSTALLER_BIN" --noexec --target "$EXTRACT_DIR"

# Verify x86 Java works
echo "  Testing x86-64 Java via Rosetta..."
JAVA=$(find "$EXTRACT_DIR/tps/lnx64" -name "java" -type f | head -1)
$JAVA -version 2>&1 | head -1
echo "  Java OK."

# -----------------------------------------------------------------------------
# 5. Setup fake uname shim (for installer architecture check)
# -----------------------------------------------------------------------------
echo ""
echo "[5/6] Setting up uname shim..."
mkdir -p "$UNAME_SHIM_DIR"
cat > "$UNAME_SHIM_DIR/uname" << 'EOF'
#!/bin/bash
if [ "$1" = "-m" ]; then
    echo "x86_64"
else
    /bin/uname "$@"
fi
EOF
chmod +x "$UNAME_SHIM_DIR/uname"
export PATH="$UNAME_SHIM_DIR:$PATH"
echo "  uname -m -> $(uname -m)"

# -----------------------------------------------------------------------------
# 6. Launch installer
# -----------------------------------------------------------------------------
echo ""
echo "[6/6] Launching Vivado/Vitis installer..."
echo ""
echo "  Recommended install path: $INSTALL_DIR"
echo "  Select: Vitis Unified Software Platform"
echo "  Devices: Zynq-7000 (at minimum)"
echo ""

mkdir -p "$INSTALL_DIR"

export _JAVA_OPTIONS="-Xmx4g"
"$EXTRACT_DIR/xsetup"

# Cleanup shim and extracted installer
rm -rf "$UNAME_SHIM_DIR"
rm -rf "$EXTRACT_DIR"

# Run post-install dependency fixer from the installed Vitis tree
if [ -f "$INSTALL_DIR/Vitis/2022.2/scripts/installLibs.sh" ]; then
    echo "  Running post-install Vitis installLibs.sh..."
    bash "$INSTALL_DIR/Vitis/2022.2/scripts/installLibs.sh"
fi

# -----------------------------------------------------------------------------
# Post-install instructions
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Installation complete!"
echo ""
echo " To launch:"
echo "   source /tools/Xilinx/Vivado/2022.2/settings64.sh"
echo "   source /tools/Xilinx/Vitis/2022.2/settings64.sh"
echo "   vivado"
echo "   vitis"
echo "=============================================="
