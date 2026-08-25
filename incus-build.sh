#!/bin/bash
# Build a prebuilt "ready" Incus image consumed by runman-agent.
# Mirrors runman-agent's ensureReadyImage(): base cloud image + preinstalled
# packages + sshd root-login config, exported as a unified image tarball.
# runman-agent's install.sh imports it with alias <base>/<arch>/ready
# (e.g. debian/13/cloud/amd64/ready) so the agent skips the runtime build.
#
# Requires a running Incus daemon (incus admin init --auto).
#
# Usage: sudo bash incus-build.sh <debian|alpine> <amd64|arm64> [outdir]
set -eu

DISTRO="${1:?usage: incus-build.sh <debian|alpine> <arch> [outdir]}"
ARCH="${2:?arch required (amd64|arm64)}"
OUTDIR="${3:-dist}"

case "$DISTRO" in
    debian) BASE_ALIAS="debian/13/cloud/$ARCH" ;;
    alpine) BASE_ALIAS="alpine/3.23/cloud/$ARCH" ;;
    *) echo "unknown distro: $DISTRO" >&2; exit 1 ;;
esac

BUILDER="builder-$DISTRO-$ARCH"
READY_ALIAS="ready-$DISTRO-$ARCH"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

cleanup() {
    incus delete -f "$BUILDER" 2>/dev/null || true
}
trap cleanup EXIT

log "Launching builder from images:$BASE_ALIAS ..."
incus launch "images:$BASE_ALIAS" "$BUILDER"

# Wait for boot / cloud-init to settle before touching the package manager
incus exec "$BUILDER" -- sh -c 'command -v cloud-init >/dev/null 2>&1 && cloud-init status --wait || true' || true

if [ "$DISTRO" = "alpine" ]; then
    INSTALL_CMD='apk update && apk add --no-cache bash wget curl openssh sshpass sudo cronie lsof iptables dos2unix'
else
    INSTALL_CMD='export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y bash wget curl openssh-server sshpass sudo cron lsof iptables dos2unix'
fi

ok=0
for i in $(seq 1 10); do
    log "Installing packages (attempt $i)..."
    if incus exec "$BUILDER" -- sh -c "$INSTALL_CMD"; then ok=1; break; fi
    sleep 10
done
[ "$ok" -eq 1 ] || { echo "package installation failed" >&2; exit 1; }

log "Configuring root access and sshd..."
incus exec "$BUILDER" -- sh -c "echo 'root:defaultpassword' | chpasswd && mkdir -p /root/.ssh && chmod 700 /root/.ssh"
incus exec "$BUILDER" -- sh -c "rm -f /etc/securetty"

# Cloud-init by default disables root login and password authentication on boot.
# Override both in the main config and drop-in directory so root login remains permitted.
incus exec "$BUILDER" -- sh -c '
    if [ -f /etc/cloud/cloud.cfg ]; then
        sed -i "s/disable_root:.*/disable_root: false/" /etc/cloud/cloud.cfg
        sed -i "s/ssh_pwauth:.*/ssh_pwauth: true/" /etc/cloud/cloud.cfg
    fi
    if [ -d /etc/cloud/cloud.cfg.d ]; then
        printf "disable_root: false\nssh_pwauth: true\n" > /etc/cloud/cloud.cfg.d/99-runman.cfg
    fi
' || true

# SSH daemon configuration (00- and 99- prefixes ensure precedence before and after other drop-ins)
incus exec "$BUILDER" -- sh -c "mkdir -p /etc/ssh/sshd_config.d && printf 'PermitRootLogin yes\nPasswordAuthentication yes\nListenAddress 0.0.0.0\nListenAddress ::\n' > /etc/ssh/sshd_config.d/00-runman.conf && cp /etc/ssh/sshd_config.d/00-runman.conf /etc/ssh/sshd_config.d/99-runman.conf"
incus exec "$BUILDER" -- sh -c "sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
if [ "$DISTRO" = "alpine" ]; then
    incus exec "$BUILDER" -- sh -c 'rc-update add sshd default || true'
    incus exec "$BUILDER" -- sh -c 'rc-update add cronie default || true'
else
    incus exec "$BUILDER" -- sh -c 'systemctl enable ssh || true'
    incus exec "$BUILDER" -- sh -c 'systemctl enable cron || true'
fi

# Never publish an image without sshd
incus exec "$BUILDER" -- sh -c 'command -v sshd >/dev/null 2>&1'

# Reset cloud-init state so per-instance user-data (root password, network)
# runs fresh on instances created from this image.
incus exec "$BUILDER" -- sh -c 'command -v cloud-init >/dev/null 2>&1 && cloud-init clean --logs || true' || true

log "Publishing image..."
incus stop "$BUILDER"
incus publish "$BUILDER" --alias "$READY_ALIAS" --compression gzip

mkdir -p "$OUTDIR"
EXPORT_TMP=$(mktemp -d)
incus image export "$READY_ALIAS" "$EXPORT_TMP/img"
mv "$EXPORT_TMP"/img* "$OUTDIR/incus-$DISTRO-$ARCH.tar.gz"
rm -rf "$EXPORT_TMP"
log "Done: $OUTDIR/incus-$DISTRO-$ARCH.tar.gz ($(du -h "$OUTDIR/incus-$DISTRO-$ARCH.tar.gz" | cut -f1))"
