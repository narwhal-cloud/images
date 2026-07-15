# fuckip.me 容器系统运行环境

[English Documentation](./README.md)

本项目是 [fuckip.me](https://fuckip.me/) 的容器系统运行环境。项目中包含了用于构建平台底层系统镜像的 Dockerfile（如 `Alpine.Dockerfile`, `Debian.Dockerfile`）。

## 自定义您的系统镜像

您可以基于本项目提供的模板，自定义并构建属于您自己的系统镜像。例如，如果您经常需要使用特定的运行时服务（例如 Node.js、Python、Nginx 或某些数据库客户端），您可以基于这些模板创建一个新的 Dockerfile 并提前安装好它们。这样可以避免每次启动容器时都重复安装依赖。

### 如何自定义

1. **构建基础镜像:**
   您可以首先使用本仓库提供的文件在本地构建基础镜像。
   ```bash
   docker build -t my-custom-debian-base -f Debian.Dockerfile .
   ```

2. **创建自定义的 Dockerfile:**
   创建一个新的 `Dockerfile`，以您刚构建的镜像作为基础，并添加您需要的服务。

   ```dockerfile
   # 使用刚刚构建的基础镜像
   FROM my-custom-debian-base:latest
   
   # 安装您需要的额外运行时服务
   # 例如，安装 Nginx 和 curl
   RUN apt-get update && apt-get install -y \
       nginx \
       curl \
       && rm -rf /var/lib/apt/lists/*
       
   # (可选) 复制您的自定义配置文件
   # COPY my-config.conf /etc/my-service/
   
   # 定义默认启动命令
   CMD ["nginx", "-g", "daemon off;"]
   ```

3. **构建并使用您的自定义镜像:**
   ```bash
   docker build -t my-custom-env .
   docker run -d my-custom-env
   ```

通过将您常用的运行时服务直接打包进镜像中，容器的启动时间将大幅缩短，同时您的运行环境也会更加稳定和一致。

## 预构建 VM 镜像（cloud-hypervisor / Incus）

除 Docker 镜像外，每月 CI 还会为 runman-agent 的 `cloudhv` 与 `incus` 驱动预构建系统镜像，并发布到滚动 GitHub Release [`vm-latest`](https://github.com/narwhal-cloud/images/releases/tag/vm-latest)：

| 资产 | 内容 |
| --- | --- |
| `cloudhv-<distro>-amd64.tar.zst` | cloud-hypervisor 镜像组（`current.raw`、`vmlinuz`、`initrd`、`cmdline`、`version`），由 install.sh 解压到 `/opt/vm-images/<distro>/` |
| `incus-<distro>-<arch>.tar.gz` | Incus unified "ready" 镜像（预装软件包 + sshd root 登录配置），由 install.sh 以 `<base>/<arch>/ready` 别名导入 |

本地构建：

```bash
sudo bash cloudhv-build.sh debian amd64 dist
sudo bash incus-build.sh debian amd64 dist   # 需要运行中的 Incus 守护进程
```
