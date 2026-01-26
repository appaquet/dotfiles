{
  inputs,
  config,
  ...
}:
{
  imports = [
    inputs.dotblip.nixosModules.default
  ];

  sops.secrets.mqtt.sopsFile = config.sops.secretsFiles.dotblip;
  dotblip = {
    enable = true;
    user = "appaquet";
    mqtt = {
      host = "haos.n3x.net";
      port = 1883;
      credentialsFile = config.sops.secrets.mqtt.path;
    };

    reporters = {
      nix = {
        enable = true;
      };

      system = {
        enable = true;
      };
    };
  };
}
