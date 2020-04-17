# This test runs k3s, verifies it launches, and verifies a pod can be run.

import ./make-test-python.nix ({ pkgs, ...} : {
  name = "k3s";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ euank ];
  };

  nodes = {
    k3s =
      { pkgs, ... }:
        {
          environment.systemPackages = [ pkgs.k3s ];

          virtualisation.k3s.enable = true;
          virtualisation.k3s.role = "server";
          virtualisation.k3s.docker = true;
          virtualisation.k3s.package = pkgs.k3s;

          users.users = {
            noprivs = {
              isNormalUser = true;
              description = "Can't access k3s by default";
              password = "*";
            };
          };
        };
    };

    testPodYaml = writeText "test.yml" ''
apiVersion: v1
kind: Pod
metadata:
  name: test
spec:
  containers:
  - name: test
    image: scratchimg
    imagePullPolicy: Never
    command: ["sh", "-c", "sleep inf"]
    volumeMounts:
    - mountPath: /nix/store
      name: nix
    - mountPath: /bin
      name: bin
  volumes:
  - name: nix
    hostPath:
      path: /nix/store
      type: Directory
  - name: bin
    hostPath:
      path: /run/current-system/sw/bin
      type: Directory
    '';

  testScript = ''
    start_all()

    k3s.wait_for_unit("k3s.service")
    k3s.succeed(
        "sudo k3s kubectl cluster-info"
    )
    k3s.fail(
        "sudo -u noprivs k3s kubectl cluster-info"
    )
    # k3s.succeed("k3s check-config") # fails with the current k3s kernel config, uncomment once this passes

    # And now run a pod and verify it completes
    k3s.succeed("echo empty > file && tar cf file | sudo docker import - scratchimg")
    k3s.succeed("sudo k3s kubectl apply -f ${testPodYaml}")
    k3s.succeed("sudo k3s kubectl wait --for 'condition=Ready' pod/test")
  '';
})
