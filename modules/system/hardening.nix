# /.dotfiles/modules/system/hardening.nix
# Low-cost kernel hardening against malware that lives only in RAM: code
# injected into a running process, run from an anonymous memfd, or hidden in
# the kernel with eBPF or a replaced kernel. None of these touch gaming
# performance. Several match the zen kernel's defaults today; they are set
# explicitly so switching kernelProvider (CachyOS, xanmod, LTS) can't loosen them.
{
  flake.modules.nixos.hardening = {
    # Blocks kexec (loading a different kernel into the running one) and
    # hibernation. Hibernation needs disk swap, and this machine only has zram,
    # so nothing is lost. Suspend to RAM is unaffected.
    security.protectKernelImage = true;

    boot.kernel.sysctl = {
      # A process can only ptrace its own children, so malware can't attach
      # to Brave, Discord or Steam and inject code. Debuggers still work on
      # programs they launch. 2+ breaks some anti-cheat, so stay at 1.
      "kernel.yama.ptrace_scope" = 1;

      # Hide kernel addresses (in /proc/kallsyms etc.) from everyone, root
      # included; kernel exploits use them to find their targets.
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;

      # Only root can load eBPF programs, and root can't turn that back off
      # without a reboot (2, the kernel default, lets root re-enable it).
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;

      # memfd_create is the usual way to run a program that never touches
      # disk. 1 makes new memfds non-executable unless the program asks for
      # MFD_EXEC explicitly. If an app breaks after this, dmesg names it.
      "vm.memfd_noexec" = 1;
    };
  };
}
