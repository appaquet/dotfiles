{
  config,
  lib,
  pkgs,
  ...
}:

let
  monitoredServices =
    # Per dataset syncoid
    (map (ds: "syncoid-${ds}") (
      lib.attrNames (lib.filterAttrs (_: ds: ds.vps_backup) config.nas.datasets)
    ))

    # Other watched services
    ++ [
      "sanoid"
      "restic-backups-home"
      "postgresql-backup-immich"
      "immich-server"
      "jellyfin"
      "offline-backup"
      "smartd"
    ];

  alertEmail = "appaquet@gmail.com";
  fromEmail = builtins.replaceStrings [ "@" ] [ "2@" ] alertEmail;
in

{
  sops.secrets."msmtp/gmail_app_password" = {
    sopsFile = config.sops.secretsFiles.servapp;
    owner = "root";
    mode = "0400";
  };

  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      port = 587;
      auth = "plain";
      tls = "on";
      tls_starttls = "on";
    };
    accounts.default = {
      host = "smtp.gmail.com";
      from = fromEmail;
      user = fromEmail;
      passwordeval = "${pkgs.coreutils}/bin/cat ${config.sops.secrets."msmtp/gmail_app_password".path}";
    };
  };

  services.zfs.zed = {
    settings = {
      ZED_EMAIL_ADDR = [ alertEmail ];
      ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
      ZED_EMAIL_OPTS = "@ADDRESS@";
      ZED_NOTIFY_INTERVAL_SECS = 3600;
      ZED_NOTIFY_VERBOSE = true;
      ZED_SCRUB_AFTER_RESILVER = true;
    };
    enableMail = true;
  };

  services.smartd = {
    enable = true;
    autodetect = true;
    defaults.autodetected = "-a -o on -s (S/../.././02|L/../../7/04)"; # Short self-test daily at 2am, long self-test Sundays at 4am
    notifications = {
      mail = {
        enable = true;
        sender = fromEmail;
        recipient = alertEmail;
        mailer = "${pkgs.msmtp}/bin/sendmail";
      };
      test = false;
    };
  };

  systemd.services = {
    "notify-email@" = {
      description = "Email notification for failed service %i";
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.msmtp
        pkgs.systemd
      ];
      scriptArgs = "%i";
      script = ''
        STATUS=$(systemctl status --full "$1" 2>&1 || true)
        {
          echo "To: ${alertEmail}"
          echo "From: servapp <${fromEmail}>"
          echo "Subject: [servapp] Service failed: $1"
          echo ""
          echo "Service $1 has failed on servapp."
          echo ""
          echo "$STATUS"
        } | msmtp ${alertEmail}
      '';
    };
  }
  // lib.genAttrs monitoredServices (_: {
    unitConfig.OnFailure = [ "notify-email@%p.service" ];
  });
}
