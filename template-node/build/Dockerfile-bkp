FROM ubuntu:22.04

ARG USER=coder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo curl git zsh ca-certificates gnupg build-essential \
    openssh-client locales bash-completion \
  && rm -rf /var/lib/apt/lists/*

# Locale/PT-BR opcional
RUN sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# \(pt_BR.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Usuário sem senha com sudo (o Coder substitui ${USER} pelo dono do workspace)
RUN useradd --groups sudo --create-home --shell /bin/bash ${USER} \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
  && chmod 0440 /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# Node LTS via nvm + pnpm
ENV NVM_DIR=/home/${USER}/.nvm
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
  && . "$NVM_DIR/nvm.sh" && nvm install --lts && nvm alias default lts/* \
  && echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc \
  && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> ~/.bashrc \
  && /bin/bash -lc ". $NVM_DIR/nvm.sh && npm i -g pnpm"

# Ajustes de conforto
RUN echo 'alias ll="ls -alF"' >> ~/.bashrc \
 && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
