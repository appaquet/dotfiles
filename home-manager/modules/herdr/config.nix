{
  config,
  lib,
  pkgs,
  ...
}:
let
  managedPlugins = config.programs.herdr.managedPlugins;
in
{
  options.programs.herdr.managedPlugins = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.package;
            description = "Plugin package to link into Herdr.";
          };

          config = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = null;
            description = "Optional TOML configuration file for the plugin.";
          };
        };
      }
    );
    default = { };
    description = "Herdr plugins managed declaratively by Home Manager.";
  };

  config = {
    home.packages = [ pkgs.python3 ];

    home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      herdr="${lib.getExe pkgs.herdr}"
      jq="${lib.getExe pkgs.jq}"
      export declaredIdsJson='${builtins.toJSON (lib.attrNames managedPlugins)}'

      if ! currentPlugins="$("$herdr" plugin list --json)"; then
        echo "Herdr server is unavailable; skipping plugin reconciliation."
        exit 0
      fi

      managedPluginsEstablished=true

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (pluginId: plugin: ''
          pluginEstablished=true

          if ! printf '%s' "$currentPlugins" | "$jq" -e \
            --arg pluginId "${pluginId}" \
            --arg pluginPath "${plugin.path}" \
            'any(.plugins[]; .plugin_id == $pluginId and .plugin_root == $pluginPath)' > /dev/null; then
            if ! "$herdr" plugin link "${plugin.path}"; then
              echo "Failed to link Herdr plugin ${pluginId}." >&2
              pluginEstablished=false
              managedPluginsEstablished=false
            fi
          fi

          if [ "$pluginEstablished" = true ]; then
            if ! "$herdr" plugin enable "${pluginId}"; then
              echo "Failed to enable Herdr plugin ${pluginId}." >&2
              pluginEstablished=false
              managedPluginsEstablished=false
            fi
          fi

          ${lib.optionalString (plugin.config != null) ''
            if [ "$pluginEstablished" = true ]; then
              if pluginDir="$("$herdr" plugin config-dir "${pluginId}")"; then
                if ! mkdir -p "$pluginDir" || ! ln -sfn "${plugin.config}" "$pluginDir/config.toml"; then
                  echo "Failed to configure Herdr plugin ${pluginId}." >&2
                  managedPluginsEstablished=false
                fi
              else
                echo "Failed to find the config directory for Herdr plugin ${pluginId}." >&2
                managedPluginsEstablished=false
              fi
            fi
          ''}
        '') managedPlugins
      )}

      if [ "$managedPluginsEstablished" = true ]; then
        if ! currentPlugins="$("$herdr" plugin list --json)"; then
          echo "Herdr server is unavailable; skipping plugin cleanup."
          exit 0
        fi

        while IFS= read -r pluginId; do
          if ! "$jq" -e -n --arg pluginId "$pluginId" \
            --argjson declaredIds "$declaredIdsJson" \
            '$declaredIds | index($pluginId) != null' > /dev/null; then
            "$herdr" plugin disable "$pluginId"
          fi
        done < <(printf '%s' "$currentPlugins" | "$jq" -r '.plugins[].plugin_id')
      fi
    '';
  };
}
