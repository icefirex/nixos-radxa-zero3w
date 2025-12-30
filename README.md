# NixOS on Radxa Zero 3W

![Radxa Zero 3W](https://docs.radxa.com/en/assets/images/radxa_zero_3w-84a1e0f01c8381ff1a202d4322f9ed17.webp)

A minimal NixOS configuration for the [Radxa Zero 3W](https://radxa.com/products/zeros/zero3w/) single-board computer with working WiFi support.

## Features

- Full NixOS support for Radxa Zero 3W (RK3566 SoC)
- **Working AIC8800 WiFi driver** with firmware
- USB gadget ethernet (SSH over USB-C)
- UART3 enabled on GPIO pins 3/5
- GPU and SCMI disabled for headless operation
- Builds flashable SD card images

## Requirements

- Nix with flakes enabled
- An aarch64-linux builder (native ARM64 machine, or cross-compilation setup)
- MicroSD card (8GB+ recommended)

## Quick Start

### 1. Configure WiFi

Edit `configuration.nix` and add your WiFi network:

```nix
networking.wireless.networks = {
  "YourSSID".pskRaw = "paste_output_from_wpa_passphrase_here";
};
```

Generate the `pskRaw` value with:
```bash
wpa_passphrase "YourSSID" "YourPassword"
```

### 2. Add your SSH key (recommended)

In `configuration.nix`, uncomment and add your SSH public key:

```nix
users.users.root.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA..."
];
```

### 3. Build the SD card image

```bash
nix build .#sdImage
```

The image will be at `./result/sd-image/nixos-sd-image-*.img`

### 4. Flash to SD card

```bash
# Find your SD card device (be careful!)
lsblk

# Flash the image
sudo dd if=./result/sd-image/nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress
sync
```

**Alternative tools:**
- **Balena Etcher** - GUI tool, works on all platforms
- **GNOME Disks** - Right-click image → "Restore Disk Image"
- **Raspberry Pi Imager** - Use "custom image" option

## Bootloader

The Radxa Zero 3W uses U-Boot as its bootloader. There are two scenarios:

### Factory U-Boot in SPI flash (most common)

If your board came with Radxa's official U-Boot in SPI flash, you're all set. The NixOS SD image uses extlinux configuration which U-Boot will automatically detect and boot.

Just flash the image and boot - no additional bootloader steps needed.

### No bootloader / custom U-Boot

If your SPI flash is empty or you want U-Boot on the SD card:

1. **Download Radxa's U-Boot** from their [releases](https://github.com/radxa/u-boot/releases) or use their official images

2. **Flash U-Boot to SD card** (before the first partition):
   ```bash
   # Download u-boot (example - check for latest)
   wget https://github.com/radxa/u-boot/releases/download/latest/zero3_u-boot.bin

   # Flash to SD card (after flashing NixOS image)
   sudo dd if=zero3_u-boot.bin of=/dev/sdX seek=64 bs=512 conv=notrunc
   sync
   ```

3. **Or flash to SPI** (permanent, survives SD card changes):
   - Boot any Linux from SD card
   - Use Radxa's `rsetup` tool or `flashcp` to write U-Boot to SPI

**Note:** The exact U-Boot binary and offset may vary. Check [Radxa's documentation](https://docs.radxa.com/en/zero/zero3) for your specific board revision.

## Flashing to eMMC (Maskrom Mode)

If your Radxa Zero 3W has eMMC storage and you want to flash directly to it (instead of using an SD card), you can use `rkdeveloptool` in maskrom mode.

### Prerequisites

Install `rkdeveloptool`:

**On NixOS:**
```bash
nix-shell -p rkdeveloptool
```

**On Debian/Ubuntu:**
```bash
sudo apt install rkdeveloptool
```

**On Arch:**
```bash
yay -S rkdeveloptool
```

Download the required files:
- **SPL Loader**: `rk3566_spl_loader_v1.xx.bin` - from [Radxa's loader repository](https://dl.radxa.com/rock3/images/loader/)
- **NixOS image**: Built with `nix build .#sdImage`

### Flashing Steps

1. **Enter maskrom mode:**
   - Locate the maskrom button (or maskrom pads) on the board
   - Hold the maskrom button while connecting USB-C to your computer
   - Release the button after connecting

2. **Verify the device is detected:**
   ```bash
   sudo rkdeveloptool ld
   ```
   You should see something like: `DevNo=1 Vid=0x2207,Pid=0x350a,LocationID=...`

3. **Download the SPL loader** (initializes DDR memory for communication):
   ```bash
   sudo rkdeveloptool db rk3566_spl_loader_v1.xx.bin
   ```
   Note: This temporarily loads the SPL into RAM - it doesn't flash anything permanently.

4. **Flash the NixOS image:**
   ```bash
   sudo rkdeveloptool wl 0 ./result/sd-image/nixos-sd-image-*.img
   ```

5. **Reset the device:**
   ```bash
   sudo rkdeveloptool rd
   ```

The board will reboot from eMMC with NixOS installed.

### If your board has no bootloader

If your SPI flash is empty (no factory U-Boot), you'll also need to flash U-Boot to eMMC:

```bash
# After step 3 (db), before flashing NixOS image:
sudo rkdeveloptool wl 64 u-boot.img
```

Get `u-boot.img` from [Radxa's U-Boot releases](https://github.com/radxa/u-boot/releases).

### 5. Boot and connect

Insert the SD card and power on. Connect via:

**WiFi:**
```bash
ssh root@radxa-zero3w  # or use the IP address
```

**USB gadget ethernet:**
Connect USB-C to your computer. Configure the host interface with IP `10.0.0.1/24`, then:
```bash
ssh root@10.0.0.2
```

Default password: `nixos` (change this!)

## Building from x86_64

If you're on an x86_64 machine, you have several options:

### Option 1: QEMU binfmt emulation (recommended)

This transparently emulates aarch64 binaries. Slow but works out of the box.

**On NixOS**, add to your system configuration:
```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

**On other distros** (Debian/Ubuntu):
```bash
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart binfmt-support
```

Then build normally:
```bash
nix build .#sdImage --system aarch64-linux
```

### Option 2: Cross-compilation (faster)

Modify `flake.nix` to cross-compile from x86_64:

```nix
{
  description = "NixOS on Radxa Zero 3W with WiFi support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      # Build on x86_64, target aarch64
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        crossSystem.config = "aarch64-unknown-linux-gnu";
      };
    in
    {
      packages.x86_64-linux.sdImage = nixos-generators.nixosGenerate {
        pkgs = pkgs;
        format = "sd-aarch64";
        modules = [
          ./configuration.nix
          { sdImage.compressImage = false; }
        ];
      };

      packages.x86_64-linux.default = self.packages.x86_64-linux.sdImage;
    };
}
```

Then build:
```bash
nix build .#sdImage
```

**Note:** Cross-compilation may fail for some packages that don't support it. QEMU binfmt is more reliable.

### Option 3: Remote aarch64 builder

If you have access to an ARM64 machine (Raspberry Pi 4, cloud instance, etc.):

```bash
# In ~/.config/nix/nix.conf or /etc/nix/nix.conf
builders = ssh://user@arm64-host aarch64-linux
```

Then Nix will automatically offload aarch64 builds to the remote machine.

## File Structure

```
.
├── flake.nix              # Nix flake entry point
├── configuration.nix      # Main NixOS configuration
├── radxa-zero3w.nix       # Hardware-specific settings (bootloader, kernel, device tree)
├── aic8800.nix            # AIC8800 WiFi driver and firmware
├── aic8800-overlay.dts    # Device tree overlay for WiFi (not currently used)
├── disable-scmi.dts       # Disables SCMI/GPU for headless operation
├── enable-uart3.dts       # Enables UART3 on GPIO pins 3/5
└── patches/
    └── aic8800-gpio-power.patch  # Fix for WiFi power sequencing
```

## Customization

This is a minimal base image. You can extend it by:

- Adding more packages to `environment.systemPackages`
- Enabling additional services
- Creating your own modules and importing them

Example:
```nix
# In configuration.nix
imports = [
  ./radxa-zero3w.nix
  ./aic8800.nix
  ./my-custom-module.nix  # Add your own
];
```

## Troubleshooting

### WiFi not working

Check if the driver loaded:
```bash
lsmod | grep aic8800
dmesg | grep -i aic8800
```

Check interface status:
```bash
ip link show wlan0
wpa_cli status
```

### No serial console output

The serial console is on UART2 at 1500000 baud (the debug pads on the board).

### USB gadget not working

Ensure you're connecting the USB-C port (not a hub) and the host has configured its interface:
```bash
# On host
sudo ip addr add 10.0.0.1/24 dev <usb-interface>
sudo ip link set <usb-interface> up
```

## Acknowledgments

- [radxa-pkg/aic8800](https://github.com/radxa-pkg/aic8800) - AIC8800 WiFi driver source
- [NixOS](https://nixos.org/) - The purely functional Linux distribution
- [nixos-generators](https://github.com/nix-community/nixos-generators) - SD card image generation

## License

[MIT License](LICENSE)
