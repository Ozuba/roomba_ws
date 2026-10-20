# syntax=docker/dockerfile:1.4
FROM ubuntu:24.04

# Expose Docker's built-in target architecture arg (amd64 / arm64)
ARG TARGETARCH

# ============================================================
# BUILD ARGUMENTS & ENVIRONMENT
# ============================================================
ARG USERNAME=rclgd
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
     PIP_BREAK_SYSTEM_PACKAGES=1 \
     LANG=en_US.UTF-8 \
     LC_ALL=en_US.UTF-8 \
     SHELL=/bin/zsh

# Keep downloaded packages in the BuildKit cache between builds
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
 && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
      > /etc/apt/apt.conf.d/keep-cache


# ============================================================
# USER CREATION
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends sudo zsh \
 && if id -u $USER_UID &>/dev/null; then userdel "$(id -un $USER_UID)"; fi \
 && groupadd --gid $USER_GID $USERNAME \
 && getent group render || groupadd render \
 && useradd --uid $USER_UID --gid $USER_GID -m -G video,render -s /bin/zsh $USERNAME \
 && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
 && chmod 0440 /etc/sudoers.d/$USERNAME


# ============================================================
# PACKAGE REPOSITORIES & LOCALE
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends \
      curl gnupg2 lsb-release ca-certificates locales \
 && locale-gen en_US en_US.UTF-8 \
 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
 \
 # ROS 2 (Jazzy / Noble)
 && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg \
 && echo "deb [arch=${TARGETARCH} signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
      http://packages.ros.org/ros2/ubuntu noble main" \
      > /etc/apt/sources.list.d/ros2.list


# ============================================================
# CORE UTILITIES & GODOT RUNTIME (Vulkan / X11)
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends \
      git cmake build-essential python3 python3-pip neovim \
      mesa-vulkan-drivers vulkan-tools \
      libgl1 libxcursor1 libxinerama1 libxrandr2 libxi6


# ============================================================
# ROS 2 (JAZZY) PACKAGES
# ============================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends \
      ros-dev-tools \
      ros-jazzy-desktop \
      ros-jazzy-rclgd


# ============================================================
# SHELL CONFIGURATION
# ============================================================
USER $USERNAME
WORKDIR /home/$USERNAME

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended \
 && echo 'source /opt/ros/jazzy/setup.zsh' >> /home/$USERNAME/.zshrc \
 && echo '[ -f /home/rclgd/rclgd_ws/install/setup.zsh ] && source /home/rclgd/rclgd_ws/install/setup.zsh' \
      >> /home/$USERNAME/.zshrc

ENV ROS_DOMAIN_ID=42

# ============================================================
# ENTRYPOINT
# ============================================================
CMD ["sleep", "infinity"]
