
Cursor Throttle & Ignore

Tools to keep editors (Cursor/VSCode) from hammering your disks.

cursor-throttle.sh — wraps Cursor’s own helper binaries (node, rg) so they always run with idle I/O and low CPU priority for any user.

cursorignore-template — a ready-made .cursorignore (blacklist) to stop indexing/searching of large binary formats in dataset trees.

These are host-side guardrails: they don’t break normal use, but they prevent background indexers from saturating HDD/NVMe and ruining interactivity.
Cursor Throttle & Ignore

Tools to keep editors (Cursor/VSCode) from hammering your disks.

cursor-throttle.sh — wraps Cursor’s own helper binaries (node, rg) so they always run with idle I/O and low CPU priority for any user.

cursorignore-template — a ready-made .cursorignore (blacklist) to stop indexing/searching of large binary formats in dataset trees.

These are host-side guardrails: they don’t break normal use, but they prevent background indexers from saturating HDD/NVMe and ruining interactivity.
# Put the script in place (if not already)
/usr/local/sbin/cursor-throttle.sh

# Wrap all users’ Cursor binaries
sudo /usr/local/sbin/cursor-throttle.sh apply

# See which binaries are wrapped, and current Cursor processes
sudo /usr/local/sbin/cursor-throttle.sh status

# Pick a PID from the list and confirm priorities:
ionice -p <PID>                # should show "Idle"
ps -o pid,ni,cmd -p <PID>      # NI should be 19

sudo /usr/local/sbin/cursor-throttle.sh restore

This renames *.real back to the original binary names and removes the wrappers.

Keep it enforced after updates (optional)

Cursor updates may drop new binaries. Use a simple timer:
# Service + timer files live here:
# /etc/systemd/system/cursor-throttle.service
# /etc/systemd/system/cursor-throttle.timer

sudo systemctl enable --now cursor-throttle.timer
# Disable later with:
# sudo systemctl disable --now cursor-throttle.timer


Why this is safe

    Only wraps files under ~/.cursor-server/ (per-user Cursor install).

    Easy to audit: check for node.real / rg.real.

    One-command restore.
2) cursorignore-template

Use this as .cursorignore at dataset mount roots (e.g., /mnt/HDD18T2/.cursorignore, /mnt/storage/.cursorignore). It allows normal text/code to be searchable but skips big binaries that cause I/O storms.

Suggested blacklist template

Save this repo file as cursorignore-template, then copy its contents into each dataset’s .cursorignore:
# Medical / scientific images
**/*.dcm
**/*.nii
**/*.nii.gz
**/*.tif
**/*.tiff
**/*.png
**/*.jpg
**/*.jpeg
**/*.bmp
**/*.cr2
**/*.nef
**/*.raw
**/*.heic
**/*.heif

# Scientific data containers
**/*.h5
**/*.hdf5
**/*.npz
**/*.npy
**/*.mat
**/*.nc
**/*.nc4
**/*.grib
**/*.parquet
**/*.orc
**/*.arrow

# Archives
**/*.zip
**/*.tar
**/*.tar.gz
**/*.tgz
**/*.7z
**/*.rar
**/*.gz
**/*.bz2

# ML / models
**/*.pt
**/*.pth
**/*.ckpt
**/*.safetensors
**/*.pb
**/*.pbtxt
**/*.onnx
**/*.tfevents.*

# Media
**/*.mp4
**/*.mov
**/*.avi
**/*.mkv
**/*.wav
**/*.mp3

# Misc binaries / blobs
**/*.iso
**/*.bin
**/*.db
**/*.sqlite
**/*.sql
# (Uncomment if you don't want Office/PDF indexed)
# **/*.pdf
# **/*.doc
# **/*.docx
# **/*.ppt
# **/*.pptx
# **/*.xls
# **/*.xlsx

.cursorignore patterns are relative; don’t use ~ or absolute paths.
Put a separate file at each root users might open as a workspace (e.g., /mnt/HDD18T2, /mnt/storage). If people open their home as a workspace and reach datasets via symlinks, you can also put a ~/.cursorignore that targets the symlink path (e.g., storage/**).
# Example: apply to a mount root
sudo tee /mnt/HDD18T2/.cursorignore < cursorignore-template
sudo tee /mnt/storage/.cursorignore < cursorignore-template

Reload Cursor/VSCode after adding (Command/Ctrl–Shift–P → Reload Window).
Accidentally wrapped the wrong thing?
sudo /usr/local/sbin/cursor-throttle.sh restore



