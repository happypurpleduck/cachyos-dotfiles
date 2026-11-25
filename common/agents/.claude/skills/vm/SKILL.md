---
name: vm
description: Create, operate and dispose of local KVM/libvirt virtual machines with the `vm` CLI. Use when a task needs a throwaway or isolated Linux machine (testing installers, packages, system services, other distros, destructive commands, multi-host setups), or when the user asks about the VMs on this machine.
---

# Local virtual machines

This machine runs KVM/QEMU through libvirt (`qemu:///system`, the same VMs
virt-manager shows). The `vm` command wraps it for non-interactive use: no
prompts, ssh in BatchMode, non-zero exit on failure. Run `vm help` for every
option.

## Typical loop

```sh
vm doctor                                  # is virtualization set up? (fix: see below)
vm create web --image debian-13 --cpus 2 --memory 2048 --disk 20
                                           # waits until ssh + cloud-init are done
vm ssh web -- 'sudo apt-get update && sudo apt-get install -y nginx'
vm cp ./site web:/tmp/site                 # copy in (or web:/var/log/x ./ to copy out)
vm snapshot web clean                      # before risky changes
vm revert web clean                        # undo them
vm list --json                             # names, state, IPs
vm delete web                              # when finished
```

- Images: `vm images` (ubuntu-26.04 default, ubuntu-24.04, debian-13, arch), or
  `--url` for any qcow2 cloud image. The first use of an image downloads it.
- The login user has your username and passwordless sudo; `vm ssh NAME -- CMD`
  returns CMD's exit status. Guests sit on a NAT network (192.168.122.0/24):
  they reach the internet, and the host reaches them at `vm ip NAME`.
- Raw `virsh`, `virt-install`, `virt-customize` and `virt-cat` also work and
  default to `qemu:///system`.

## Rules

- Only delete, revert or force-stop VMs you created in this task unless the
  user asks. `vm list` shows `MANAGED=no` for VMs that `vm` did not create, and
  `vm delete` refuses those without `--force`: never pass `--force` on your own.
- Name VMs after their purpose (`pg-test`, `ci-arch`) and delete them when the
  task ends, unless the user wants to keep them; tell the user which VMs remain.
- Mind the host: it is the user's desktop. Keep to a few VMs at once and modest
  sizes (2 CPUs / 4 GiB / 20 GiB unless the task needs more).
- `vm view NAME` opens a window on the user's screen; use it only when they ask.

## When `vm` fails

- `missing virsh…` → the user needs `dot optional virtualization`.
- `no access to qemu:///system` → the user needs `vm setup` once (asks for sudo).
- `this session predates joining the libvirt group` → the user must log out and
  in again, or restart T3 Code / the agent, so new processes get the group.
- Sandboxed agent modes may block the libvirt socket or ssh to the guest; ask the
  user to allow the `vm` command or run with full access.

These are steps for the user, not for you: report them and stop instead of
trying sudo yourself.
