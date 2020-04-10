{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.k3s;
in
{
  # interface
  options.services.k3s = {
    enable = mkEnableOption "k3s";

    package = mkOption {
      type = types.package;
      default = pkgs.k3s;
      defaultText = "pkgs.k3s";
      example = literalExample "pkgs.k3s";
      description = ''
      '';
    };

    role = mkOption {
      description = ''
        Whether k3s should run as a server or agent.
        Note that the server, by default, also runs as an agent.
      '';
      default = "server";
      type = types.enum [ "server" "agent" ];
    };

    serverAddr = mkOption {
      type = types.str;
      description = "The k3s server to connect to. This option only makes sense for an agent.";
      example = "https://10.0.0.10:6443";
    };

    token = mkOption {
      type = types.str;
      description = "The k3s token to use when connecting to the server. This option only makes sense for an agent.";
    };

    docker = mkOption {
      type = types.bool;
      default = false;
      description = "Use docker to run containers rather than the built-in containerd.";
    };

    extraFlags = mkOption {
      description = "Extra flags to pass to the k3s command.";
      default = "";
      example = "--no-deploy traefik --cluster-cidr 10.24.0.0/16";
    };

    disableAgent = mkOption {
      type = types.bool;
      default = false;
      description = "Only run the server. This option only makes sense for a server.";
    };
  };

  # implementation

  config = mkIf cfg.enable {
    virtualisation.docker = mkIf cfg.docker {
      enable = mkDefault true;
    };

    services.k3s = mkIf (cfg.role == "server") {
      serverAddr = "";
      token = "";
    };

    systemd.services.k3s = {
      description = "k3s service";
      after = mkIf cfg.docker [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        # Taken from https://github.com/rancher/k3s/blob/v1.17.4+k3s1/contrib/ansible/roles/k3s/node/templates/k3s.service.j2
        Type = "notify";
        KillMode = "process";
        Delegate = "yes";
        LimitNOFILE = "infinity";
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        TasksMax = "infinity";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = concatStringsSep " \\\n " (
          [
            "${cfg.package}/bin/k3s ${cfg.role}"
          ] ++ (optional cfg.docker "--docker")
          ++ (optional cfg.disableAgent "--disable-agent")
          ++ (optional (cfg.role == "agent") "--server ${cfg.serverAddr} --token ${cfg.token}")
          ++ [ cfg.extraFlags ]
        );
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
