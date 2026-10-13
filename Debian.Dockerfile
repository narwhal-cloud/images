FROM debian:latest

ENV LANG=en_US.UTF-8

RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    echo "deb http://cloudflaremirrors.com/debian stable main" > /etc/apt/sources.list

# 安装必要的软件（包括 systemd）
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    systemd \
    systemd-sysv \
    openssh-server \
    passwd \
    curl \
    iproute2 \
    net-tools \
    iputils-ping \
    btop \
    vim \
    unzip \
    ca-certificates \
    wget \
    locales \
    tzdata \
    sudo

# 删除不需要的包来减少服务
RUN apt-get remove -y --purge \
    dbus \
    systemd-timesyncd \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 删除不需要的 systemd 服务文件
RUN cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/*

# 禁用剩余的不必要服务
RUN ln -sf /dev/null /etc/systemd/system/systemd-logind.service && \
    ln -sf /dev/null /etc/systemd/system/systemd-user-sessions.service && \
    ln -sf /dev/null /etc/systemd/system/systemd-resolved.service && \
    ln -sf /dev/null /etc/systemd/system/systemd-networkd.service && \
    ln -sf /dev/null /etc/systemd/system/getty.target && \
    ln -sf /dev/null /etc/systemd/system/getty@.service && \
    ln -sf /dev/null /etc/systemd/system/user@.service

# 限制 journald 内存占用:默认日志存于 /run/log/journal(tmpfs),上限为 /run 大小的 10%,
# 会计入实例内存且面板 RAM 不显示,小内存套餐会被挤进 swap
RUN mkdir -p /etc/systemd/journald.conf.d && \
    printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=8M\nRuntimeMaxFileSize=2M\n' \
      > /etc/systemd/journald.conf.d/00-runman.conf

# 启用 SSH 服务
RUN systemctl enable ssh

RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    echo "deb https://cloudflaremirrors.com/debian stable main\ndeb https://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list

# 配置 locale
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen

# 设置 root 密码和 SSH 配置
RUN echo "root:defaultpassword" | chpasswd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    mkdir -p /var/run/sshd && \
    sed -i '/pam_nologin.so/d' /etc/pam.d/sshd && \
    sed -i '/pam_nologin.so/d' /etc/pam.d/login && \
    rm -f /run/nologin /var/run/nologin

# 允许 root 登录和密码认证
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 删除装包时生成的 host key,改为容器首次启动时生成(避免所有容器共用同一套 key)
RUN rm -f /etc/ssh/ssh_host_* && \
    mkdir -p /etc/systemd/system/ssh.service.d && \
    printf '[Service]\nExecStartPre=\nExecStartPre=/usr/bin/ssh-keygen -A\nExecStartPre=/usr/sbin/sshd -t\n' \
      > /etc/systemd/system/ssh.service.d/host-keygen.conf

EXPOSE 22

# 使用 systemd 作为初始化系统
CMD ["/lib/systemd/systemd"]
