FROM debian:latest
ENV DEBIAN_FRONTEND=noninteractive

# 设置语言和时区
ENV LANG=zh_CN.UTF-8
ENV TZ=Asia/Shanghai

RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    echo "deb http://cloudflaremirrors.com/debian stable main" > /etc/apt/sources.list

# 安装必要的软件（包括 locales 和 tzdata 用于语言和时区设置）
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
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

RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/* && \
    echo "deb https://cloudflaremirrors.com/debian stable main\ndeb https://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list

# 配置语言环境（zh_CN.UTF-8）
RUN sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=zh_CN.UTF-8

# 配置时区（Asia/Shanghai）
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# 设置 root 密码和 SSH 配置
RUN echo "root:defaultpassword" | chpasswd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    mkdir -p /var/run/sshd

# 允许 root 登录和密码认证
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 生成 SSH 主机密钥
RUN ssh-keygen -A
EXPOSE 22
CMD ["/usr/bin/systemctl", "domain"]