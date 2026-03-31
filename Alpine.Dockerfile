FROM alpine:latest

ENV LANG=en_US.UTF-8

RUN apk update && apk add --no-cache \
    openssh-server \
    openrc \
    shadow \
    curl \
    iproute2 \
    net-tools \
    btop \
    vim \
    unzip \
    ca-certificates \
    wget \
    tzdata \
    bash \
    && rm -rf /var/cache/apk/*

# 设置 root 密码和 SSH 配置
RUN echo "root:defaultpassword" | chpasswd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# SSH 配置
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# 配置 OpenRC
RUN mkdir -p /run/openrc && \
    touch /run/openrc/softlevel && \
    rc-update add sshd default


# 修复 OpenRC 在容器中的问题并禁用不必要的服务
RUN sed -i 's/^\(tty\d\)/#\1/' /etc/inittab && \
    sed -i \
    -e 's/#rc_env_allow=".*"/rc_env_allow="*"/' \
    -e 's/#rc_crashed_stop=.*/rc_crashed_stop=NO/' \
    -e 's/#rc_crashed_start=.*/rc_crashed_start=YES/' \
    -e 's/#rc_provide=".*"/rc_provide="loopback net"/' \
    /etc/rc.conf && \
    rm -f /etc/init.d/hwdrivers \
          /etc/init.d/hwclock \
          /etc/init.d/modules \
          /etc/init.d/modules-load \
          /etc/init.d/modloop \
          /etc/init.d/bootmisc \
          /etc/init.d/hostname \
          /etc/init.d/killprocs \
          /etc/init.d/savecache \
          /etc/init.d/mount-ro \
          /etc/init.d/swap \
          /etc/init.d/urandom

EXPOSE 22

CMD ["/sbin/init"]
