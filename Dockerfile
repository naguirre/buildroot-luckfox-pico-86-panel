FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
 && apt -y upgrade \
 && apt -y install build-essential  bash bc binutils build-essential bzip2 \
	sudo git zsh curl \
        cpio g++ gcc git gzip locales libncurses5-dev libdevmapper-dev \
        libsystemd-dev make mercurial whois patch perl python3 rsync sed \
        tar vim unzip wget bison flex libssl-dev libfdt-dev curl file swig\
        u-boot-tools python3-setuptools python3-dev \
    && rm -rf /var/lib/apt-lists/*


RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen

ARG USERNAME="build"
ARG USER_UID="1000"
ARG USER_GID=${USER_UID}
RUN groupadd --gid ${USER_GID} ${USERNAME} || true \
 && adduser --uid ${USER_UID} --gid ${USER_GID} ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${USERNAME}

RUN apt update \
 && apt -y upgrade \
 && apt -y install build-essential fish bat lsd\
    && rm -rf /var/lib/apt-lists/*

USER build

RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.5/zsh-in-docker.sh)" -- \
    -t agnoster

RUN echo 'command -v lsd > /dev/null && alias ls="lsd --date=relative --group-dirs=first --size=short"' >> ${HOME}/.zshrc
RUN echo "command -v lsd > /dev/null && alias tree='lsd --tree'" >> ${HOME}/.zshrc
#RUN echo "command -v lsd > /dev/null && alias ls='lsd --group-dirs first'" >> ${HOME}/.zshrc
RUN echo "command -v bat > /dev/null && alias cat='bat --pager=never'" >> ${HOME}/.zshrc
