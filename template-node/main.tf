terraform {
  required_providers {
    coder  = { source = "coder/coder" }
    docker = { source = "kreuzwerker/docker" }
  }
}

provider "coder" {}
provider "docker" {}

# ====== VARIÁVEL: GID do grupo docker no HOST ======
variable "docker_gid" {
  type    = string
  default = "988"  # SUBSTITUA/ sobrescreva ao criar workspace
}

# ====== CONTEXTO ======
data "coder_workspace"       "me" {}
data "coder_workspace_owner" "me" {}
data "coder_provisioner"     "me" {}

locals { username = data.coder_workspace_owner.me.name }

# ====== AGENT ======
resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -euo pipefail

    # --- alinhar grupo 'docker' ao GID do host para acessar o socket ---
    if [ -n "${DOCKER_GID:-}" ]; then
      if ! getent group docker >/dev/null; then
        sudo groupadd -g "$DOCKER_GID" docker || true
      fi
      sudo usermod -aG docker "$(whoami)" || true
    fi

    # --- Docker CLI + Compose plugin no workspace ---
    if ! command -v docker >/dev/null; then
      sudo apt-get update
      sudo apt-get install -y ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce-cli docker-compose-plugin
    fi

    # --- code-server + Claude Code (IDE web) ---
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
    /tmp/code-server/bin/code-server --install-extension anthropic.claude-copilot || true

    # iniciar code-server (auth via Coder)
    /tmp/code-server/bin/code-server \
      --auth none \
      --port 13337 \
      --disable-telemetry \
      --user-data-dir /home/${local.username}/.local/share/code-server \
      --extensions-dir /home/${local.username}/.local/share/code-server/extensions \
      /home/${local.username} \
      >/tmp/code-server.log 2>&1 &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU"
    key          = "0_cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "RAM"
    key          = "1_ram"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

# ====== PERSISTÊNCIA ======
resource "docker_volume" "home" {
  name      = "coder-${data.coder_workspace.me.id}-home"
  lifecycle { ignore_changes = all }
}

# ====== IMAGEM ======
resource "docker_image" "img" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context    = "./build"
    build_args = { USER = local.username }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

# ====== CONTAINER DO WORKSPACE ======
resource "docker_container" "ws" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.img.name
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DOCKER_GID=${var.docker_gid}"
  ]

  # faz host.docker.internal funcionar em Linux
  host { host = "host.docker.internal" ip = "host-gateway" }

  # HOME persistente
  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  # socket do Docker do HOST (para usar docker compose no workspace)
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = false
  }
}

# ====== APP code-server ======
resource "coder_app" "code" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}
