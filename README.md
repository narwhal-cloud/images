# fuckip.me Container System Runtime Environment

[中文文档](./README_zh.md)

This project provides the base container system runtime environment for [fuckip.me](https://fuckip.me/). It contains Dockerfiles (e.g., `Alpine.Dockerfile`, `Debian.Dockerfile`) designed to build the underlying system images used by the platform.

## Customizing Your Own System Image

You can use these templates as a base to customize your own system images. For example, if you frequently need specific runtime services (such as Node.js, Python, Nginx, or database clients), you can create a new Dockerfile that extends these templates. This saves you from having to reinstall dependencies every time a container starts.

### How to Customize

1. **Build the base image from this repository:**
   You can build the base image locally using the provided files.
   ```bash
   docker build -t my-custom-debian-base -f Debian.Dockerfile .
   ```

2. **Create your custom Dockerfile:**
   Create a new `Dockerfile` that uses your newly built image as the base, and add your required services.

   ```dockerfile
   # Use the base image you just built
   FROM my-custom-debian-base:latest
   
   # Install additional runtime services you need
   # For example, installing Nginx and curl
   RUN apt-get update && apt-get install -y \
       nginx \
       curl \
       && rm -rf /var/lib/apt/lists/*
       
   # (Optional) Add your custom configuration files
   # COPY my-config.conf /etc/my-service/
   
   # Define the default command or entrypoint
   CMD ["nginx", "-g", "daemon off;"]
   ```

3. **Build and use your custom image:**
   ```bash
   docker build -t my-custom-env .
   docker run -d my-custom-env
   ```

By building your custom services directly into the image, your container startup times will be significantly faster and your runtime environment will be more consistent.

## Prebuilt VM Images (cloud-hypervisor / Incus)

Besides the Docker images, the monthly CI also builds prebuilt system images for the runman-agent `cloudhv` and `incus` drivers and publishes them to the rolling GitHub release [`vm-latest`](https://github.com/narwhal-cloud/images/releases/tag/vm-latest):

| Asset | Content |
| --- | --- |
| `cloudhv-<distro>-amd64.tar.zst` | cloud-hypervisor image set (`current.raw`, `vmlinuz`, `initrd`, `cmdline`, `version`), extracted by install.sh into `/opt/vm-images/<distro>/` |
| `incus-<distro>-<arch>.tar.gz` | Incus unified "ready" image (preinstalled packages + sshd root-login config), imported by install.sh as `<base>/<arch>/ready` |

Build locally:

```bash
sudo bash cloudhv-build.sh debian amd64 dist
sudo bash incus-build.sh debian amd64 dist   # requires a running Incus daemon
```
