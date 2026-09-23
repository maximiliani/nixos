{ ... }:
{
  virtualisation.oci-containers.containers.headscale-console = {
    image = "ghcr.io/rickli-cloud/headscale-console:latest";
    pull = "newer";
    networks = [ "podman:mac=9a:14:44:a5:f1:d6" ];
  };
}
