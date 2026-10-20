# /.dotfiles/modules/tailscale.nix
# Tailscale client, for reaching family machines (remote support) over the
# tailnet. Nothing is opened on the LAN or internet: Tailscale punches out
# through NAT on its own and falls back to its relays.
{
  flake.modules.nixos.tailscale = {
    services.tailscale.enable = true;
  };
}
