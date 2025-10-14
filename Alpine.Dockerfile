FROM alpine:latest

# 设置语言和时区
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Shanghai

# 安装必要的软件
RUN apk update && apk add --no-cache \
    openssh \
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
    bash

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

# 自定义脚本
RUN echo 'curl -s https://fuckip.me/res/fuckme-alpine.sh | bash' > /usr/local/bin/fuckme && chmod +x /usr/local/bin/fuckme
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
