{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libraspberrypi # Provides vcgencmd, GPU tools
    raspberrypi-eeprom # Provides rpi-eeprom-update, rpi-eeprom-config
  ];
}
