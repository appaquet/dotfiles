{ ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      sshAgentSlotUnitCheck = import ./checks/ssh-agent-slot-unit.nix { inherit pkgs; };
    in
    {
      checks.ssh-agent-slot-unit = sshAgentSlotUnitCheck;
    };
}
