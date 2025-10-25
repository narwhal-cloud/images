FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive

# 设置语言和时区
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Shanghai

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
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# 启用 SSH 服务
RUN systemctl enable ssh

RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    echo "deb https://cloudflaremirrors.com/debian stable main\ndeb https://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list

# 配置时区（Asia/Shanghai）
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

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

# 生成 SSH 主机密钥
RUN ssh-keygen -A

# 自定义脚本
RUN echo 'bash <(curl -sL https://fuckip.me/res/fuckme-debian.sh)' > /usr/local/bin/fuckme && chmod +x /usr/local/bin/fuckme


EXPOSE 22

# 使用 systemd 作为初始化系统
CMD ["/lib/systemd/systemd"]