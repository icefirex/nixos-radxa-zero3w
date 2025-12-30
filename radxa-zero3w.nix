# Hardware configuration for Radxa Zero 3W (RK3566)
{ ... }: {
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.enableRedistributableFirmware = true;

  boot.kernelParams = [ "console=ttyS2,1500000n8" "loglevel=4" ];

  hardware.deviceTree = {
    enable = true;
    filter = "*rk3566-radxa-zero-3*.dtb";
    overlays = [
      {
        name = "disable-scmi";
        dtsFile = ./disable-scmi.dts;
      }
      {
        name = "enable-uart3";
        dtsFile = ./enable-uart3.dts;
      }
    ];
  };
}
