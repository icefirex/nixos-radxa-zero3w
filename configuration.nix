# Minimal NixOS configuration for Radxa Zero 3W
{ pkgs, lib, ... }:
{
  imports = [
    ./radxa-zero3w.nix
    ./aic8800.nix
  ];

  system.stateVersion = "25.11";

  # Filesystem configuration (overridden by nixos-generators for images)
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Hostname
  networking.hostName = "radxa-zero3w";

  # WiFi - configure your network here
  # Option 1: Using wpa_passphrase to generate pskRaw:
  #   wpa_passphrase "YourSSID" "YourPassword"
  # Option 2: Using plain text PSK (less secure):
  #   networks."YourSSID".psk = "YourPassword";
  networking.wireless = {
    enable = true;
    interfaces = [ "wlan0" ];
    networks = {
      # Add your WiFi network(s) here:
      # "YourSSID".pskRaw = "paste_output_from_wpa_passphrase_here";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
  };

  # SSH
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings.PermitRootLogin = "yes";
  };

  # Root user - set your own password or SSH key
  users.users.root = {
    initialPassword = "nixos"; # Change this!
    # Add your SSH public key(s) here:
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAA..."
    # ];
  };

  # Time sync (needed for SSH key verification)
  services.timesyncd.enable = true;

  # Basic packages
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    iproute2
    curl
  ];

  # USB gadget ethernet - allows SSH over USB-C
  # Connect to 10.0.0.2 from host (configure host side as 10.0.0.1)
  boot.kernelModules = [ "g_ether" ];
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.2";
    prefixLength = 24;
  }];
}
