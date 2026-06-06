# Vivado / Vitis 2022.2 on Apple Silicon (M4 Pro)

## Environment

| Component | Version |
|-----------|---------|
| Mac | Apple M4 Pro, 14-core, 48GB RAM |
| macOS | 26.5.1 (Build 25F80) |
| Parallels | 26.3.3 (57507) |
| Guest OS | Ubuntu 22.04.5 LTS aarch64 |
| Vivado | 2022.2 |
| Vitis | 2022.2 (Eclipse-based) |

---

## Overview

Vivado and Vitis are x86-64 only. On Apple Silicon (aarch64) we use:
- **Parallels Rosetta Linux** to transparently run x86-64 ELF binaries
- **binfmt_misc** kernel handler to auto-invoke Rosetta for x86-64 binaries
- **Multiarch (amd64)** apt packages for x86-64 shared libraries

---

## Step 1 — Install Ubuntu Server 22.04 ARM

Ubuntu does not provide a desktop ARM image directly. Start from the server image:

1. Download **Ubuntu Server 22.04 ARM** ISO from https://ubuntu.com/download/server/arm
2. In Parallels: **File → New → Install Windows or another OS from a DVD or image file**
3. Select the downloaded ISO and proceed with installation
4. After server install, upgrade and install desktop:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ubuntu-desktop-minimal
sudo reboot
```

---

## Step 2 — Install Parallels Tools

Parallels Tools enables the Rosetta Linux share (`/media/psf/RosettaLinux/`).

1. In Parallels menu: **Actions → Install Parallels Tools**
2. Inside the VM:

```bash
cd "/media/$USER/Parallels Tools"
sudo ./install
sudo reboot
```

> Parallels Tools mounts as a folder under `/media/$USER/Parallels Tools/`. On older Parallels versions it may appear as a CD drive at `/dev/cdrom` — if the folder path is missing, use `sudo mount /dev/cdrom /mnt && sudo /mnt/install` instead.

3. After reboot, verify:

```bash
ls /media/psf/RosettaLinux/
# Should show: rosetta
```

---

## Step 3 — Download Vitis 2022.2 Web Installer

1. Go to https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vitis.html
2. Download **Vitis Unified Software Platform 2022.2 — Linux Web Installer**
   - Filename: `Xilinx_Unified_2022.2_1014_8888_Lin64.bin`

---

## Step 4 — Install Vivado / Vitis

Two options — pick one:

### Option A — Run the install script (automated)

```bash
chmod +x install_vivado_vitis_2022.2.sh
sudo bash install_vivado_vitis_2022.2.sh ~/Downloads/Xilinx_Unified_2022.2_1014_8888_Lin64.bin
```

The script will:
1. Verify Rosetta is available
2. Register Rosetta as binfmt handler (persistent across reboots)
3. Add amd64 architecture and install all required x86-64 libraries
4. Extract the installer
5. Set up a temporary uname shim to bypass the architecture check
6. Launch the GUI installer with 4GB heap; run post-install `Vitis/2022.2/scripts/installLibs.sh` on exit

### Option B — Manual install

Run all commands from the [Session Log](#session-log) section at the bottom of this document in order.

---

In the GUI installer (either option) select:
- **Product:** Vitis Unified Software Platform
- **Devices:** Zynq-7000 (add others as needed)
- **Install path:** `/tools/Xilinx`

---

## Step 5 — Post-Install Configuration

Add to `~/.bashrc`:

```bash
source /tools/Xilinx/Vivado/2022.2/settings64.sh
source /tools/Xilinx/Vitis/2022.2/settings64.sh
```

Apply immediately:

```bash
source ~/.bashrc
```

---

## Step 6 — Launch

```bash
vivado
vitis
```

---

## Troubleshooting

### `ERROR: This installation is not supported on 32 bit platforms`
The installer checks `uname -m` and rejects `aarch64`. The install script handles this
automatically with a uname shim. If running manually:
```bash
export PATH="/usr/local/bin/vivado_shims:$PATH"
```

### `libtinfo.so.5: cannot open shared object file`
```bash
sudo apt install -y libtinfo5:amd64
```

### `libpixman-1.so.0: cannot open shared object file`
```bash
sudo apt install -y libpixman-1-0:amd64
```

### `libswt-pi4-gtk` / Vitis Eclipse GUI fails to start
```bash
sudo apt install -y libgtk-3-0:amd64 libgdk-pixbuf2.0-0:amd64 \
    libcairo2:amd64 libpango-1.0-0:amd64 libwebkit2gtk-4.0-37:amd64
```

### `libgssapi_krb5.so.2: cannot open shared object file`
```bash
sudo apt install -y libkrb5-3:amd64 libgssapi-krb5-2:amd64
```

### amd64 packages 404 on apt update
`ports.ubuntu.com` does not carry amd64 packages. The script adds the correct
`archive.ubuntu.com` source automatically. If doing manually:
```bash
sudo tee /etc/apt/sources.list.d/amd64.list << 'EOF'
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
sudo sed -i 's/^deb http/deb [arch=arm64] http/' /etc/apt/sources.list
sudo apt update
```

### Rosetta binfmt not persistent after reboot
The script installs a systemd service automatically. To check:
```bash
systemctl status rosetta-binfmt
cat /proc/sys/fs/binfmt_misc/rosetta
```

---

## x86-64 Libraries Reference

All libraries installed with `:amd64` suffix via multiarch:

| Package | Purpose |
|---------|---------|
| `libc6:amd64` | C runtime |
| `libstdc++6:amd64` | C++ runtime |
| `libtinfo5:amd64` | Terminal info (Vivado Tcl) |
| `libncurses5:amd64` | NCurses |
| `libpixman-1-0:amd64` | Pixel manipulation (Vivado GUI) |
| `libkrb5-3:amd64` | Kerberos (Vitis) |
| `libgssapi-krb5-2:amd64` | GSSAPI (Vitis) |
| `libgtk-3-0:amd64` | GTK3 (Vitis Eclipse SWT) |
| `libwebkit2gtk-4.0-37:amd64` | WebKit (Vitis Eclipse) |
| `libxext6:amd64` | X11 extensions |
| `libxrender1:amd64` | X Render extension |
| `libxtst6:amd64` | X Test extension |
| `fontconfig:amd64` | Font configuration |

---

## Session Log

Actual commands run during the initial manual setup. Used as the basis for `install_vivado_vitis_2022.2.sh`.

```bash
# --- Initial Ubuntu setup ---
sudo apt update
sudo apt upgrade
sudo init 6

sudo apt install ubuntu-desktop-minimal
sudo init 6

# --- Install Parallels Tools ---
cd /media/max/Parallels\ Tools/
sudo ./install
sudo init 6

# --- Verify Rosetta ---
ls /media/psf/RosettaLinux/
ls /proc/sys/fs/binfmt_misc/
cat /proc/sys/fs/binfmt_misc/rosetta
echo ':rosetta:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/media/psf/RosettaLinux/rosetta:CF' | sudo tee /proc/sys/fs/binfmt_misc/register
cat /proc/sys/fs/binfmt_misc/rosetta

# --- Add amd64 arch and install x86-64 libs ---
sudo dpkg --add-architecture amd64
sudo apt update
sudo tee /etc/apt/sources.list.d/amd64.list << 'EOF'
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
sudo sed -i 's/^deb http/deb [arch=arm64] http/' /etc/apt/sources.list
sudo apt update
sudo apt install -y \
    libc6:amd64 \
    libstdc++6:amd64 \
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
    fontconfig:amd64 \
    fonts-dejavu-core \
    xfonts-base \
    libkrb5-3:amd64 \
    libgssapi-krb5-2:amd64 \
    libpixman-1-0:amd64

# --- uname shim ---
uname -m
sudo mkdir -p /usr/local/bin/vivado_shims
sudo tee /usr/local/bin/vivado_shims/uname << 'EOF'
#!/bin/bash
if [ "$1" = "-m" ]; then
    echo "x86_64"
else
    /bin/uname "$@"
fi
EOF
sudo chmod +x /usr/local/bin/vivado_shims/uname
export PATH="/usr/local/bin/vivado_shims:$PATH"
uname -m

# --- Extract and launch installer ---
ls -l
sh Xilinx_Unified_2022.2_1014_8888_Lin64.bin --noexec --target /tmp/vivado_extract
/tmp/vivado_extract/tps/lnx64/jre11.0.11_9/bin/java -version

sudo bash -c 'PATH="/usr/local/bin/vivado_shims:$PATH" _JAVA_OPTIONS="-Xmx4g" DISPLAY=:0 /tmp/vivado_extract/xsetup'

# --- Post-install: fix Vitis Eclipse dependencies ---
sudo /tools/Xilinx/Vitis/2022.2/scripts/installLibs.sh

# GTK/WebKit libs were needed after first Vitis launch attempt:
sudo apt install -y \
    libgtk-3-0:amd64 \
    libgdk-pixbuf2.0-0:amd64 \
    libcairo2:amd64 \
    libpango-1.0-0:amd64 \
    libpangocairo-1.0-0:amd64 \
    libatk1.0-0:amd64 \
    libglib2.0-0:amd64 \
    libwebkit2gtk-4.0-37:amd64
```
