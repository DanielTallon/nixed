# /.dotfiles/modules/zram.nix
# Compressed RAM-backed swap. Pairs with vm.swappiness=100 in kernel.nix —
# with no disk swap configured, we want the kernel to reach for zram early
# since it's cheap/fast, unlike real disk swap.
{
  flake.modules.nixos.zram = {
    zramSwap = {
      enable = true;
      memoryPercent = 25; # ~25% of RAM as compressed swap capacity
      algorithm = "zstd"; # better ratio than lz4, still fast on modern CPUs
    };
  };
}
