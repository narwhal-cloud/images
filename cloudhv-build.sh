#!/bin/bash
# Build the prebuilt cloud-hypervisor image set consumed by runman-agent.
# Produces: <outdir>/cloudhv-<distro>-<arch>.tar.zst containing
#   current.raw  vmlinuz  initrd  cmdline  version
# The layout mirrors what runman-agent's install.sh used to build locally
# in update_vm_images(), so install.sh can simply extract it into
# /opt/vm-images/<distro>/.
#
# Usage: sudo bash cloudhv-build.sh <debian|alpine> [arch] [outdir]
set -eu

DISTRO="${1:?usage: cloudhv-build.sh <debian|alpine> [arch] [outdir]}"
ARCH="${2:-amd64}"
OUTDIR="${3:-dist}"

[ "$(id -u)" -eq 0 ] || { echo "must run as root (loop mounts required)" >&2; exit 1; }
# cloud-hypervisor direct kernel boot images are only produced for amd64 today;
# arm64 needs an uncompressed kernel Image and different console/cmdline.
[ "$ARCH" = "amd64" ] || { echo "only amd64 cloud-hypervisor images are supported" >&2; exit 1; }

for t in wget qemu-img fdisk blkid zstd tar; do
    command -v "$t" >/dev/null 2>&1 || { echo "missing tool: $t" >&2; exit 1; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# List all partitions of a raw image as "offset size" pairs (in bytes)
list_partitions() {
    local img="$1"
    fdisk -l "$img" | awk -v img="$img" '
        $0 ~ "^"img {
            # fdisk may insert a boot flag "*" as $2 — shift fields accordingly
            if ($2 == "*") { start=$3; sectors=$5 }
            else            { start=$2; sectors=$4 }
            offset = start * 512
            size   = sectors * 512
            if (offset > 0 && size > 0)
                print offset, size
        }
    '
}

# Extract kernel and initrd from a raw disk image, scanning all partitions.
extract_kernel() {
    local raw="$1" outdir="$2"
    local mnt vmlinuz initrd found=0

    log "Extracting kernel and initrd..."
    while read -r offset size; do
        mnt=$(mktemp -d)
        if ! mount -o loop,offset="$offset",sizelimit="$size",ro "$raw" "$mnt" 2>/dev/null; then
            rmdir "$mnt" 2>/dev/null || true
            continue
        fi

        vmlinuz=$(find "$mnt" "$mnt/boot" -maxdepth 1 -name "vmlinuz-*" 2>/dev/null | grep -v rescue | sort -V | tail -1)
        initrd=$(find "$mnt" "$mnt/boot" -maxdepth 1 \( -name "initrd*" -o -name "initramfs-*.img" \) 2>/dev/null \
                 | grep -v rescue | sort -V | tail -1)

        if [ -n "$vmlinuz" ] && [ -n "$initrd" ]; then
            cp "$vmlinuz" "$outdir/vmlinuz"
            cp "$initrd"  "$outdir/initrd"
            found=1
        fi

        umount "$mnt" && rmdir "$mnt"
        [ "$found" -eq 1 ] && break
    done < <(list_partitions "$raw")

    [ "$found" -eq 1 ] || { echo "vmlinuz/initrd not found in any partition of $raw" >&2; exit 1; }
    log "Kernel: $(basename "$vmlinuz")"
}

build_debian() {
    local base="https://cloud.debian.org/images/cloud/trixie/latest"
    local name="debian-13-generic-${ARCH}.qcow2"

    log "Downloading $name ..."
    wget -q "$base/$name" -O "$WORK/image.qcow2"

    log "Verifying SHA512..."
    local remote_sha
    remote_sha=$(wget -qO- "$base/SHA512SUMS" | awk -v f="$name" '$2 == f {print $1}')
    [ -n "$remote_sha" ] || { echo "cannot resolve SHA512 for $name" >&2; exit 1; }
    echo "$remote_sha  $WORK/image.qcow2" | sha512sum -c - >/dev/null

    log "Converting to raw..."
    qemu-img convert -f qcow2 -O raw "$WORK/image.qcow2" "$WORK/current.raw"
    rm -f "$WORK/image.qcow2"

    extract_kernel "$WORK/current.raw" "$WORK"
    echo "root=/dev/vda1 rw console=ttyS0,115200" > "$WORK/cmdline"
    echo "debian-13-$(date -u +%Y%m%d)" > "$WORK/version"
}

build_alpine() {
    local mach="x86_64"
    local cloud_base="" latest_qcow2=""

    # Resolve latest nocloud cloud image from latest-stable, falling back to
    # previous v3.x releases if latest-stable has no cloud directory yet.
    if wget -q --spider "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/cloud/" 2>/dev/null; then
        cloud_base="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/cloud"
        latest_qcow2=$(wget -qO- "$cloud_base/" 2>/dev/null \
            | grep -o 'nocloud_alpine-[0-9][^"]*-'"$mach"'-bios-cloudinit-r[0-9]*\.qcow2' \
            | sort -uV | tail -1 || true)
    fi

    if [ -z "$latest_qcow2" ]; then
        log "No cloud image in latest-stable, searching previous v3.x releases..."
        local versions ver
        versions=$(wget -qO- "https://dl-cdn.alpinelinux.org/alpine/" 2>/dev/null \
            | grep -o 'href=["'\''\]\?v3\.[0-9]*/\?["'\''\]\?' \
            | sed -e 's/href=//' -e 's/["'\''/]//g' \
            | sort -t. -k2,2rn || true)

        for ver in $versions; do
            local test_url="https://dl-cdn.alpinelinux.org/alpine/$ver/releases/cloud"
            if wget -q --spider "$test_url/" 2>/dev/null; then
                local qcow
                qcow=$(wget -qO- "$test_url/" 2>/dev/null \
                    | grep -o 'nocloud_alpine-[0-9][^"]*-'"$mach"'-bios-cloudinit-r[0-9]*\.qcow2' \
                    | sort -uV | tail -1 || true)
                if [ -n "$qcow" ]; then
                    cloud_base="$test_url"
                    latest_qcow2="$qcow"
                    log "Found cloud image in $ver: $latest_qcow2"
                    break
                fi
            fi
        done
    fi

    [ -n "$latest_qcow2" ] || { echo "could not resolve Alpine cloud image filename" >&2; exit 1; }
    log "Downloading $latest_qcow2 ..."
    wget -q "$cloud_base/$latest_qcow2" -O "$WORK/image.qcow2"

    log "Verifying SHA512..."
    local remote_sha
    remote_sha=$(wget -qO- "$cloud_base/${latest_qcow2}.sha512" | awk '{print $1}')
    [ -n "$remote_sha" ] || { echo "cannot resolve SHA512 for $latest_qcow2" >&2; exit 1; }
    echo "$remote_sha  $WORK/image.qcow2" | sha512sum -c - >/dev/null

    log "Converting to raw..."
    qemu-img convert -f qcow2 -O raw "$WORK/image.qcow2" "$WORK/current.raw"
    rm -f "$WORK/image.qcow2"

    # Alpine nocloud image has no partition table — raw ext4 filesystem on the device.
    local mnt
    mnt=$(mktemp -d)
    mount -o loop,ro "$WORK/current.raw" "$mnt"
    cp "$mnt/boot/vmlinuz-virt"   "$WORK/vmlinuz"
    cp "$mnt/boot/initramfs-virt" "$WORK/initrd"
    umount "$mnt" && rmdir "$mnt"
    log "Kernel: vmlinuz-virt"

    local root_uuid
    root_uuid=$(blkid -s UUID -o value "$WORK/current.raw")
    [ -n "$root_uuid" ] || { echo "could not detect root UUID from Alpine image" >&2; exit 1; }

    echo "root=UUID=$root_uuid rw modules=sd-mod,usb-storage,ext4 console=ttyS0,115200" > "$WORK/cmdline"
    echo "$latest_qcow2" | grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' | head -1 > "$WORK/version"
}

case "$DISTRO" in
    debian) build_debian ;;
    alpine) build_alpine ;;
    *) echo "unknown distro: $DISTRO" >&2; exit 1 ;;
esac

mkdir -p "$OUTDIR"
log "Packing cloudhv-$DISTRO-$ARCH.tar.zst ..."
tar --sparse -I 'zstd -19 -T0' -cf "$OUTDIR/cloudhv-$DISTRO-$ARCH.tar.zst" \
    -C "$WORK" current.raw vmlinuz initrd cmdline version
log "Done: $OUTDIR/cloudhv-$DISTRO-$ARCH.tar.zst ($(du -h "$OUTDIR/cloudhv-$DISTRO-$ARCH.tar.zst" | cut -f1))"
