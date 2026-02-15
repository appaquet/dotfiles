{ ... }:
{
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = 8053;
    mutableSettings = false;

    settings = {
      users = [
        {
          name = "appaquet";
          password = "$2y$05$aZKGyCD4nGzYWvl7avCoiOR3/YyWaiRZi3AiFbhfpCyZNIRc9Bp3i";
        }
      ];

      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };

      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
      };

      filters =
        map
          (url: {
            enabled = true;
            url = url;
          })
          [
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt" # AdGuard DNS filter
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt" # AdAway Default Blocklist
            # "https://example.com/custom-blocklist.txt"
          ];

      user_rules = [
        "@@||appsflyersdk.com^" # ws promos
        "@@||braze.com^" # ws promos
        "@@||featureassets.org^" # ws promos
        "@@||prodregistryv2.org^" # ws promos
        # Block: "||blocked-domain.com^"
        # Allow: "@@||allowed-domain.com^"
      ];
    };
  };
}
