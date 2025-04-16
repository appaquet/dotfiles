{
  pkgs,
  secrets,
  config,
  ...
}:

let
  vpn-shell = pkgs.writeShellApplication {
    name = "vpn-shell";

    bashOptions = [
      "errexit"
      "nounset"
    ]; # by default it adds pipefail, which is a pain

    runtimeInputs = with pkgs; [
      docker
    ];

    text = ''
      INIT_DIR=$(pwd)

      SCRIPT_DIR="$(cd "$(dirname "$\{BASH_SOURCE[0]\}")" && pwd)"
      cd "$SCRIPT_DIR"

      # Build the image if it doesn't exist
      if ! docker images | grep -q openvpn-shell; then
        echo "Container image doesn't exist, building it..."

        cat << EOF > Dockerfile
      FROM haugene/transmission-openvpn:latest

      RUN apt update && \
          apt install -y fish sudo

      RUN groupadd --gid 100 users2
      RUN adduser --uid 1000 --gid 100 --disabled-password --gecos "" --shell /usr/bin/bash appaquet
      RUN mkdir -p /usr/local/gcloud && chown 1000:100 /usr/local/gcloud
      RUN echo 'appaquet ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
      EOF

        docker build -t openvpn-shell .

        rm Dockerfile
      fi

      # shellcheck source=/dev/null
      source ${secrets.common.nordvpn}

      # Start the vpn container if it doesn't already run
      if ! docker ps | grep -q openvpn-shell; then
        trap 'docker rm -f openvpn-shell' EXIT
        docker run --rm \
          --name openvpn-shell \
          --hostname openvpn-shell \
          --cap-add=NET_ADMIN \
          --device /dev/net/tun \
          --dns 8.8.8.8 \
          --dns 8.8.4.4 \
          -v /etc/localtime:/etc/localtime:ro \
          -v ${config.home.homeDirectory}:${config.home.homeDirectory} \
          -v /nix:/nix \
          -v /mnt:/mnt \
          -v /run:/run \
          -e OPENVPN_PROVIDER=NORDVPN \
          -e OPENVPN_USERNAME="$OPENVPN_USERNAME" \
          -e OPENVPN_PASSWORD="$OPENVPN_PASSWORD" \
          -e CONFIG_MOD_PING=0 \
          -e OPENVPN_OPTS="--ping 10 --pull-filter ignore ping" \
          openvpn-shell &
      fi

      # Loop to check if container is running
      while ! docker ps | grep -q openvpn-shell; do
        echo "Waiting for openvpn-shell container to start..."
        sleep 2
      done
      echo "openvpn-shell container is running."


      # Give it some time and then start a shell
      sleep 3
      docker exec -it openvpn-shell sudo -u appaquet ${pkgs.fish}/bin/fish \
          --private \
          -C "cd $INIT_DIR" \
          -C "set -ge fish_user_path" \
          -C "set -Ua fish_user_paths /nix/var/nix/profiles/default/bin" \
          -C "set -Ua fish_user_paths ${config.home.homeDirectory}/.nix-profile/bin" \
          -C "set -Ua fish_user_paths ${config.home.homeDirectory}/.local/utils/"
    '';
  };

in
{
  home.packages = [ vpn-shell ];
}
