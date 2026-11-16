{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      sshAgentSlotUnitCheck = import ./checks/ssh-agent-slot-unit.nix { inherit pkgs; };
      sshAgentBridgeUnitCheck = import ./checks/ssh-agent-bridge-unit.nix {
        inherit pkgs;
        home-manager = inputs.home-manager;
      };
    in
    {
      checks.ssh-agent-slot-unit = sshAgentSlotUnitCheck;

      checks.ssh-agent-bridge-unit = sshAgentBridgeUnitCheck;
    };
}
