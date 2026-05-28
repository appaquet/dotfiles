# Demo aggregator: merges individual source-set module files into a single
# attrset for use by `AGENT_SOURCE_MODE=mixed ./x agent build/check`.
# Each sub-file declares one owner branch so cross-owner flat scope.blocks.*
# references and HM module merging can be proven independently.
import ./demo-blocks.nix
// import ./demo-commands.nix
// import ./demo-agents.nix
// import ./demo-skills.nix
// import ./demo-instructions.nix
