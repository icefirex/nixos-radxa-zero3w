# NixOS on Radxa Zero 3W

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

## Building on x86_64

If you don't have a native aarch64 machine, you can use:

1. **QEMU binfmt** (easiest):
   ```bash
   # On NixOS, add to configuration.nix:
   boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
   ```

2. **Remote builder**: Configure a remote aarch64 machine in your Nix config.

3. **Cross-compilation**: Modify the flake to use cross-compilation (more complex).

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

MIT License - see individual files for their respective licenses.
