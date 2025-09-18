FROM ubuntu:22.04

ARG USER=coder
ENV DEBIAN_FRONTEND=noninteractive

# Pacotes base
RUN apt-get update && apt-get install -y \
    sudo curl git zsh ca-certificates gnupg build-essential \
    openssh-client locales bash-completion unzip \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev fonts-powerline \
    fonts-firacode\
  && rm -rf /var/lib/apt/lists/*

# Locales (pt_BR opcional)
RUN sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# \(pt_BR.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Usuário com sudo NOPASSWD
RUN useradd --groups sudo --create-home --shell /bin/bash ${USER} \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
  && chmod 0440 /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# --- NVM + Node 22.12.0 + Corepack (yarn/pnpm) ---
ENV NVM_DIR=/home/${USER}/.nvm
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
  && . "$NVM_DIR/nvm.sh" && nvm install 22.12.0 && nvm alias default 22.12.0 \
  && corepack enable \
  && corepack prepare yarn@stable --activate \
  && corepack prepare pnpm@latest --activate

# --- zsh + oh-my-zsh (unattended) + Starship ---
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true \
  && curl -sS https://starship.rs/install.sh | sh -s -- -y || true

# Shell default zsh
RUN sudo chsh -s "$(which zsh)" ${USER}

# .zshrc amigável ao VS Code (code-server)
RUN bash -lc 'cat > ~/.zshrc << "EOF"\n\
# VS Code shell integration\n\
if [ -n "$VSCODE_SHELL_INTEGRATION" ] && [ -r "$VSCODE_SHELL_INTEGRATION" ]; then . "$VSCODE_SHELL_INTEGRATION"; fi\n\
\n\
export PATH="$HOME/.local/bin:$PATH"\n\
# NVM\n\
export NVM_DIR="$HOME/.nvm"\n\
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n\
# oh-my-zsh\n\
export ZSH="$HOME/.oh-my-zsh"\n\
ZSH_THEME="robbyrussell"\n\
plugins=(git)\n\
[ -d "$ZSH" ] && . "$ZSH/oh-my-zsh.sh"\n\
# starship\n\
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"\n\
alias ll="ls -alF"\n\
EOF'

# .bashrc (caso use bash)
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc \
 && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> ~/.bashrc \
 && echo 'eval "$(starship init bash)"' >> ~/.bashrc \
 && echo 'alias ll="ls -alF"' >> ~/.bashrc
