{ ... }:

{
  virtualisation.docker.enable = true;

  users.users.appaquet = {
    extraGroups = [
      "docker"
    ];
  };
}
