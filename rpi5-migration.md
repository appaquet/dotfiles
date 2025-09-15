# Migration: nix-community/raspberry-pi-nix → nvmd/nixos-raspberrypi

## Context

The nix-community/raspberry-pi-nix project has been deprecated/archived, and the recommended
migration path is to nvmd/nixos-raspberrypi. This migration is necessary to maintain up-to-date
Raspberry Pi support in NixOS configurations.

**Current Setup:**

- Raspberry Pi 5 (piapp) running NixOS
- Using nix-community/raspberry-pi-nix with bcm2712 board configuration
- uboot disabled, using standard boot process
- OS installed on NVMe drive (migrated from initial SD card boot)

**Target Setup:**

- nvmd/nixos-raspberrypi flake-based configuration
- RPi5-specific modules with optimized packages
- Better support for nixos-anywhere and declarative deployments

## Requirements

- ✅ **In-place upgrade**: Must be able to upgrade existing piapp installation without issues
- ✅ **NVMe boot compatibility**: Must maintain NVMe boot functionality (current setup)
- ✅ **SD card creation**: Must be able to burn SD cards for future Pi deployments
- ✅ **Backward compatibility**: Existing configuration should work with minimal changes
- ✅ **Documentation**: Update setup instructions for future reference

## Questions

- [ ] Should we test the migration on a spare SD card first before upgrading the live system?
- [ ] Do we want to use the installer images for new deployments or continue building custom images?
- [ ] Should we add binary cache configuration for faster builds?
- [ ] Should we add Raspberry Pi tools (rpi-eeprom-update, vcgencmd) to system packages?

## Files

- **flake.nix**: Main flake configuration file. Contains input definitions and nixosConfigurations.
  Updated to replace raspberry-pi-nix input with nixos-raspberrypi and modify piapp configuration
  modules.

- **nixos/piapp/configuration.nix**: Raspberry Pi 5 system configuration file. Contains
  hardware-specific settings like board type and boot configuration. Updated to remove
  raspberry-pi-nix attribute set as it's handled by modules. Will also add Raspberry Pi
  tools (libraspberrypi, raspberrypi-eeprom) to environment.systemPackages.

- **nixos/cachix.nix**: Binary cache configuration file imported by common.nix. Contains
  substituters and trusted-public-keys for faster builds. Updated to include
  nixos-raspberrypi.cachix.org for nvmd flake binary cache.

- **README.md**: Project documentation with setup instructions. Contains Raspberry Pi setup section
  (lines 86-101) that references the old nix-community/raspberry-pi-nix approach. Updated to reflect
  new nvmd/nixos-raspberrypi methodology.

## TODO

- [ ] Update flake.nix input from raspberry-pi-nix to nixos-raspberrypi
- [ ] Update piapp nixosConfiguration modules
- [ ] Remove raspberry-pi-nix configuration block from nixos/piapp/configuration.nix
- [ ] Test build configuration locally
- [ ] Update README.md Raspberry Pi section
- [ ] Add Raspberry Pi tools to piapp configuration
- [ ] Test SD card image creation
- [ ] Perform in-place upgrade on piapp
- [ ] Verify system functionality after migration
- [ ] Add nixos-raspberrypi cachix to nixos/cachix.nix
- [ ] Test EEPROM update functionality
- [ ] Document any additional troubleshooting steps discovered

## Pull requests

### Summary

In this PR, I migrated the Raspberry Pi NixOS configuration from the deprecated nix-community/raspberry-pi-nix to the actively maintained nvmd/nixos-raspberrypi flake. This migration provides better module organization, active maintenance, optimized packages with binary cache support, and improved support for declarative deployments with nixos-anywhere.

## Migration Steps

### 1. Update Flake Input

Replace the deprecated input in `flake.nix`:

```nix
# Before
raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

# After  
nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";
```

Update the input reference in the outputs section:

```nix
# Before
inputs@{
  # ...
  raspberry-pi-nix,
  # ...
}

# After
inputs@{
  # ...
  nixos-raspberrypi,
  # ...
}
```

### 2. Update piapp NixOS Configuration Modules

In the nixosConfigurations.piapp section, replace the modules:

```nix
# Before
piapp = nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  specialArgs = {
    inherit (self) common;
    inherit inputs;
    secrets = secrets.init "linux";
  };
  modules = [
    nixosOverlaysModule
    raspberry-pi-nix.nixosModules.raspberry-pi
    raspberry-pi-nix.nixosModules.sd-image
    ./nixos/piapp/configuration.nix
  ];
};

# After
piapp = nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  specialArgs = {
    inherit (self) common;
    inherit inputs;
    secrets = secrets.init "linux";
  };
  modules = [
    nixosOverlaysModule
    nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    ./nixos/piapp/configuration.nix
  ];
};
```

### 3. Update Hardware Configuration

Remove the raspberry-pi-nix configuration block from `nixos/piapp/configuration.nix`:

```nix
# Remove this entire block:
raspberry-pi-nix = {
  uboot.enable = false;
  board = "bcm2712";
};
```

The nvmd modules automatically handle the RPi5 configuration, including:

- Boot loader setup (defaults to kernelboot for RPi5)
- Firmware partition management at `/boot/firmware`
- Hardware-specific kernel and device tree configuration

### 4. Testing Strategy

#### Phase 1: Local Build Test

```bash
# Dry run to check for configuration issues
nix build '.#nixosConfigurations.piapp.config.system.build.toplevel' --dry-run

# Full build test
nix build '.#nixosConfigurations.piapp.config.system.build.toplevel'
```

#### Phase 2: SD Card Image Test

```bash
# Build SD card image
nix build '.#nixosConfigurations.piapp.config.system.build.sdImage'

# Check image is created successfully
ls -la result/
```

#### Phase 3: In-Place Upgrade

```bash
# On the piapp system
sudo nixos-rebuild switch --flake github:appaquet/dotfiles#piapp

# Verify system is running correctly
systemctl status
journalctl -b
```

### 5. Update Documentation

Update the Raspberry Pi section in `README.md` (lines 86-101):

```markdown
## Initial setup for Raspberry Pi

### Notes
* https://github.com/nvmd/nixos-raspberrypi is used to provide comprehensive Raspberry Pi support with optimized packages and active maintenance.
* The nvmd flake provides hardware-specific modules that automatically handle kernel, firmware, and bootloader configuration.
* Binary cache is available for faster builds: https://nixos-raspberrypi.cachix.org
* I use a Mac VM to build the initial SD card to prevent potentially recompiling the whole kernel on a poor Rpi.

### Steps

#### Option A: Custom Configuration (Recommended)
1. On a UTM NixOS host, create the RPi NixOS config, and then build an SD card: `nix build '.#nixosConfigurations.piapp.config.system.build.sdImage'`

2. Copy the result image to a SD card for initial boot: `zstdcat result/*.img.zstd | dd of=/dev/sdX status=progress`

3. Boot the RPi from SD card and change password.

4. **NVMe Migration**: Copy system to NVMe and update boot configuration:
   ```bash
   # Format NVMe drive
   sudo fdisk /dev/nvme0n1  # Create partitions
   
   # Copy system to NVMe
   sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 status=progress
   
   # Update bootloader to use NVMe
   # Edit /boot/firmware/config.txt and add: boot_ramdisk=1
   ```

5. Follow normal procedure to setup home-manager & rebuild NixOS.

#### Option B: Generic Installer Images
For new Pi deployments, you can use pre-built installer images:

```bash
# Build generic RPi5 installer  
nix build github:nvmd/nixos-raspberrypi#installerImages.rpi5

# Flash to SD card
zstdcat result/*.img.zstd | dd of=/dev/sdX status=progress
```

**Note**: With nvmd/nixos-raspberrypi, NVMe boot is handled automatically. The firmware partition management supports both SD card initial setup and subsequent NVMe boot without manual intervention.

```

## Troubleshooting Guide

### Build Issues

#### Problem: Module conflicts or missing dependencies
```

error: The option 'hardware.raspberry-pi' is not defined

```
**Solution:** Ensure you're using the correct module import:
```nix
nixos-raspberrypi.nixosModules.raspberry-pi-5.base
```

#### Problem: Kernel compilation on weak hardware

**Solution:** Add the nvmd/nixos-raspberrypi binary cache to your existing cachix.nix:

```nix
# Update nixos/cachix.nix
{ ... }:
{
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://nixos-raspberrypi.cachix.org"  # Add this line
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixos-raspberrypi.cachix.org-1:5GyIy0VdlEI1Tw9lCw4KOHUckjJkbNmGfcxRtBaDC6k="  # Add this line
      ];
    };
  };
}
```

### Boot Issues

#### Problem: System won't boot after migration

**Solution:** Boot into older generation:

1. On RPi boot screen, select older NixOS generation
2. Revert flake changes and rebuild
3. Check boot logs: `journalctl -b`

#### Problem: Firmware partition issues

```
mount: /boot/firmware: mount point does not exist
```

**Solution:** The nvmd modules manage `/boot/firmware` automatically. If you had custom `/boot` mounts, remove them.

### Network Issues

#### Problem: Network configuration not working after migration

**Solution:** The module doesn't change network configuration. Verify your existing network settings in `nixos/piapp/configuration.nix` are still correct.

### SD Card Creation Issues

#### Problem: Image build fails with space issues

```
error: disk full or quota exceeded
```

**Solution:**

1. Clean nix store: `nix-store --gc`
2. Use binary cache to avoid local builds
3. Build on a machine with more storage

#### Problem: Image doesn't boot on Pi

**Solution:**

1. Verify you're using the correct image for your Pi model
2. Check SD card isn't corrupted: `fsck /dev/sdX`
3. Try rebuilding the image

### Performance Issues

#### Problem: Slow builds

**Solution:**

1. Configure binary cache (see above)
2. Use `nixos-rebuild switch --option builders-use-substitutes true`
3. Consider using `nixos-anywhere` for remote deployments

## Advanced Configuration

### NVMe Boot Support

Your current NVMe boot setup is fully supported by nvmd/nixos-raspberrypi. The migration will maintain your existing NVMe boot configuration:

- **Boot partition**: `/boot/firmware` on the NVMe drive (managed automatically)
- **Boot method**: RPi5 defaults to `kernelboot` which supports NVMe
- **Multi-generation boot**: New kernel boot method supports multiple NixOS generations

**No additional configuration needed** - the nvmd modules automatically handle NVMe boot detection and configuration.

### Raspberry Pi Tools (EEPROM Updates, vcgencmd)

Unlike Raspberry Pi OS, NixOS doesn't include RPi-specific tools by default. Add these to your system configuration:

```nix
# In nixos/piapp/configuration.nix
environment.systemPackages = with pkgs; [
  libraspberrypi    # Provides vcgencmd, GPU tools
  raspberrypi-eeprom  # Provides rpi-eeprom-update, rpi-eeprom-config
];
```

**Available tools after adding packages:**
- `vcgencmd` - Query system info (temperature, clock speeds, voltages)
- `rpi-eeprom-update` - Update bootloader EEPROM firmware
- `rpi-eeprom-config` - Configure EEPROM settings

**Usage examples:**
```bash
# Check current EEPROM version
sudo rpi-eeprom-update

# Update EEPROM to latest stable
sudo rpi-eeprom-update -a

# Check Pi temperature and frequency
vcgencmd measure_temp
vcgencmd measure_clock arm
```

**Note:** Both packages are needed together due to dependencies (rpi-eeprom-update requires vcgencmd in PATH).

### Custom Boot Configuration

If you need custom boot settings, use `hardware.raspberry-pi.config`:

```nix
hardware.raspberry-pi.config = {
  all = {
    # Custom config.txt options
    dtoverlay = "vc4-kms-v3d";
    gpu_mem = 128;
    # NVMe-specific settings (usually not needed)
    # dtparam = "nvme";
  };
};
```

### Alternative Boot Methods

The nvmd flake supports multiple boot methods:

```nix
# Use U-Boot instead of direct kernel boot
boot.loader.raspberryPi.bootMethod = "uboot";

# Use new generation kernel boot (recommended for new installations)
boot.loader.raspberryPi.bootMethod = "kernel";
```

### Additional Modules

Common additional modules you might want:

```nix
imports = [
  nixos-raspberrypi.nixosModules.raspberry-pi-5.base
  nixos-raspberrypi.nixosModules.raspberry-pi-5.bluetooth
  nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
  nixos-raspberrypi.nixosModules.usb-gadget-ethernet  # For Pi Zero
];
```

## Maintenance Notes

### Updating the Flake

Keep the nvmd flake updated:

```bash
# Update flake inputs
nix flake update

# Or update specific input
nix flake lock --update-input nixos-raspberrypi
```

### Monitoring Upstream Changes

- Watch the nvmd/nixos-raspberrypi repository for updates
- Check release notes for breaking changes
- Test updates on non-production systems first

### Backup Strategy

Before major updates:

1. Create system generation backup
2. Document current working configuration
3. Test rollback procedure

### Binary Cache Maintenance

Monitor binary cache availability:

- Primary: <https://nixos-raspberrypi.cachix.org>
- Fallback: Build locally if cache is unavailable

## Migration Checklist

- [ ] Update flake.nix input
- [ ] Update nixosConfiguration modules  
- [ ] Remove old raspberry-pi-nix config block
- [ ] Test local build
- [ ] Test SD card image creation
- [ ] Update README.md documentation
- [ ] Perform in-place system upgrade
- [ ] Verify all services work correctly
- [ ] Test network connectivity
- [ ] Test SSH access
- [ ] Verify boot process
- [ ] Document any custom changes needed
- [ ] Update binary cache configuration
- [ ] Test rollback procedure
