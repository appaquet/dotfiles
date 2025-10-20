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

### 3. Create Hardware Configuration

**CRITICAL:** Create `nixos/piapp/hardware-configuration.nix` with explicit filesystem definitions:

```bash
# On piapp system, generate hardware config
sudo nixos-generate-config --show-hardware-config
```

Create the file with `lib.mkDefault` for all filesystem options (required for sd-image compatibility):

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Note: lib.mkDefault is used here because this hardware-configuration.nix is shared
  # by both the regular piapp config (uses NVMe UUIDs below) and piapp-sdimage config
  # (needs to override with /dev/disk/by-label/NIXOS_SD for SD card images).
  # Without mkDefault, the two configurations would conflict.
  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-uuid/YOUR-ROOT-UUID";
    fsType = lib.mkDefault "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = lib.mkDefault "/dev/disk/by-uuid/YOUR-BOOT-UUID";
    fsType = lib.mkDefault "vfat";
    options = lib.mkDefault [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
```

Import it in `nixos/piapp/configuration.nix`:

```nix
{
  imports = [
    ./hardware-configuration.nix  # Add this line first
    ../common.nix
    # ... other imports
  ];
}
```

Remove the raspberry-pi-nix configuration block:

```nix
# Remove this entire block:
raspberry-pi-nix = {
  uboot.enable = false;
  board = "bcm2712";
};
```

### 3a. Configure Boot Partition Limits

**CRITICAL for 128MB boot partitions:** Limit generations to avoid filling the boot partition.

Each generation requires ~74MB (53MB kernel/initrd + 21MB firmware). With a 128MB partition, you can only fit 1 generation safely.

Add to `nixos/piapp/configuration.nix`:

```nix
# Limit boot generations to 1 due to small 128MB boot partition
# (each generation is ~74MB: 53MB kernel/initrd + 21MB firmware)
boot.loader.raspberryPi.configurationLimit = 1;
```

**Note:** This means you won't have boot-time rollback ability. Consider resizing the boot partition to 256MB or 512MB if you need multiple generations.

### 4. Testing Strategy

#### Phase 1: Local Build Test

**Use MACHINE_KEY to test from any system:**

```bash
# Test piapp configuration builds correctly
MACHINE_KEY=appaquet@piapp ./x nixos check

# Test SD image configuration builds correctly
nix eval --raw ".#nixosConfigurations.piapp-sdimage.config.system.build.toplevel"
```

**IMPORTANT:** Always test with `MACHINE_KEY=appaquet@piapp ./x nixos check` before pushing changes to production. This validates the entire configuration locally.

#### Phase 2: SD Card Image Separation

**CRITICAL:** Separate SD image configuration from running system to avoid conflicts.

Create a separate `piapp-sdimage` configuration in flake.nix that includes the sd-image module:

```nix
piapp-sdimage = nixos-raspberrypi.lib.nixosSystem {
  system = "aarch64-linux";
  specialArgs = {
    inherit (self) common;
    inherit inputs nixos-raspberrypi;
    secrets = secrets.init "linux";
  };
  modules = [
    {
      imports = with nixos-raspberrypi.nixosModules; [
        raspberry-pi-5.base
        sd-image  # Only include this in the SD image config
      ];
    }
    ./nixos/piapp/configuration.nix
  ];
};
```

Update the `x` script sdimage command to use this config:

```bash
sdimage)
  shift
  echo "Building SD card image for ${HOSTNAME}..."
  ${NIX_BUILDER} build ".#nixosConfigurations.${HOSTNAME}-sdimage.config.system.build.sdImage"
  # ... rest of script
  ;;
```

**Why this is needed:** The sd-image module adds `-sd-card` to the system name and overrides filesystem definitions. This conflicts with the running system configuration.

#### Phase 3: In-Place Upgrade

**Important:** If the binary cache isn't yet in your system configuration, you can add it via command-line flags to avoid rebuilding everything:

```bash
# On the piapp system - dry run with binary cache
sudo nixos-rebuild dry-activate --flake .#piapp \
  --option extra-substituters "https://cache.nixos.org/ https://nix-community.cachix.org https://nixos-raspberrypi.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="

# After verifying dry-run, do actual switch with same flags
sudo nixos-rebuild switch --flake .#piapp \
  --option extra-substituters "https://cache.nixos.org/ https://nix-community.cachix.org https://nixos-raspberrypi.cachix.org" \
  --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="

# Verify system is running correctly
systemctl status
journalctl -b
```

**Note:** `/etc/nix/nix.conf` is read-only on NixOS (managed by the system), so you cannot manually edit it. Use command-line options instead when the cache isn't yet in your configuration.

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

#### Problem: Boot partition full during migration

```
cp: error writing '/boot/firmware/nixos-kernels/xxx.tmp': No space left on device
```

**This is the most common migration issue with 128MB boot partitions.**

**Immediate Solution:**

1. Check space: `df -h /boot/firmware`
2. Remove old kernel files from previous boot method:
   ```bash
   sudo rm /boot/firmware/kernel.img /boot/firmware/initrd /boot/firmware/cmdline.txt
   sudo rm /boot/firmware/*.tmp*
   ```
3. If still full and stuck mid-migration, use the nuclear option:
   ```bash
   # WARNING: Only do this if you're stuck mid-migration
   sudo rm -rf /boot/firmware/*
   # Then retry: sudo nixos-rebuild switch --flake .#piapp ...
   # NixOS will regenerate everything from the nix store
   ```

**Preventive Solution:**

Add `boot.loader.raspberryPi.configurationLimit = 1` to your configuration BEFORE migrating (see Step 3a above).

**Long-term Solution:**

Resize boot partition to 256MB or 512MB:
1. Boot from SD card
2. Use fdisk/parted to resize /boot/firmware partition on NVMe
3. This allows keeping multiple generations for rollback

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

### Service Failures After Migration

#### Problem: UPS services fail with systemd credentials error

```
upsd.service: Failed to set up credentials: Protocol error
upsmon.service: Failed to set up credentials: Protocol error
```

**Cause:** Systemd version upgrade (257.5 → 257.9) changed credentials handling behavior. This is not a migration issue but triggered by the systemd upgrade.

**Solution:**

This issue is under investigation. The UPS services use systemd LoadCredential to load secrets, which may need updates for systemd 257.9.

**Workaround:** If UPS monitoring isn't critical, you can temporarily disable the services:

```nix
systemd.services.upsd.enable = false;
systemd.services.upsmon.enable = false;
```

The rest of the system (WiFi, SSH, networking) should work normally despite this failure.

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

### Pre-Migration
- [ ] Update flake.nix input from raspberry-pi-nix to nixos-raspberrypi
- [ ] Update nixosConfiguration to use nixos-raspberrypi.lib.nixosSystem helper
- [ ] Remove raspberry-pi-nix overlays from nixosOverlays
- [ ] Remove raspberry-pi-nix config block from piapp/configuration.nix
- [ ] Add Raspberry Pi tools (libraspberrypi, raspberrypi-eeprom) to system packages
- [ ] Update binary cache configuration in nixos/cachix.nix

### Hardware Configuration
- [ ] Generate hardware-configuration.nix on running piapp system
- [ ] Create hardware-configuration.nix with lib.mkDefault for all filesystem options
- [ ] Import hardware-configuration.nix in piapp/configuration.nix
- [ ] Add boot.loader.raspberryPi.configurationLimit = 1 for 128MB boot partitions

### SD Image Separation
- [ ] Create separate piapp-sdimage nixosConfiguration in flake.nix
- [ ] Include sd-image module only in piapp-sdimage config
- [ ] Update x script sdimage command to use ${HOSTNAME}-sdimage pattern

### Testing
- [ ] Test with MACHINE_KEY=appaquet@piapp ./x nixos check
- [ ] Test SD image config: nix eval --raw ".#nixosConfigurations.piapp-sdimage.config.system.build.toplevel"
- [ ] Verify nvd diff shows expected changes (kernel upgrade, firmware, etc.)

### Migration Execution
- [ ] Clean old boot files if boot partition is near full
- [ ] Run dry-activate with binary cache flags
- [ ] Review service restart warnings
- [ ] Execute nixos-rebuild switch with binary cache flags
- [ ] Monitor for boot partition space errors
- [ ] If stuck, use nuclear option: sudo rm -rf /boot/firmware/*

### Post-Migration
- [ ] Verify system booted successfully
- [ ] Test network connectivity (WiFi/Ethernet)
- [ ] Test SSH access
- [ ] Check boot logs: journalctl -b
- [ ] Verify RPi tools work (vcgencmd, rpi-eeprom-update)
- [ ] Test UPS services if applicable (may need systemd credentials fix)
- [ ] Document any service failures for future investigation
- [ ] Update README.md documentation

### Future Considerations
- [ ] Consider resizing boot partition to 256MB or 512MB for multiple generations
- [ ] Test SD card image creation: MACHINE_KEY=appaquet@piapp ./x nixos sdimage
- [ ] Test rollback procedure (limited with configurationLimit=1)
