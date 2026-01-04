# NVMe Stability Kernel Parameters

This system was configured to improve NVMe stability by disabling aggressive power-saving features that can cause NVMe devices to disappear under load.

## Parameters Applied

The following kernel parameters were added to GRUB:

```
nvme_core.default_ps_max_latency_us=0 pcie_aspm=off
```

### What they do
- `nvme_core.default_ps_max_latency_us=0`  
  Disables NVMe internal low-power states to prevent controller lockups.

- `pcie_aspm=off`  
  Disables PCIe Active State Power Management to prevent PCIe link power-state flapping.

## How this was implemented

1. Edit the GRUB configuration:
   ```bash
   sudo vim /etc/default/grub
   ```

2. Modify the line:
   ```text
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
   ```

   to:
   ```text
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvme_core.default_ps_max_latency_us=0 pcie_aspm=off"
   ```

3. Regenerate GRUB and reboot:
   ```bash
   sudo update-grub
   sudo shutdown -h now
   ```

4. Verify after reboot:
   ```bash
   cat /proc/cmdline
   ```

## Reason

These settings were applied to address NVMe devices being intermittently removed from the system and only reappearing after a cold power-off.

---
