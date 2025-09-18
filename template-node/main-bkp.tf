terraform {
  required_providers {
    coder  = { source = "coder/coder" }
    docker = { source = "kreuzwerker/docker" }
  }
}

provider "coder" {}
provider "docker" {}

data "coder_workspace"       "me" {}
data "coder_workspace_owner" "me" {}
data "coder_provisioner"     "me" {}

locals { username = data.coder_workspace_owner.me.name }

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # Instala e inicia o code-server (VS Code web) + Claude Code
  startup_script = <<-EOT
    set -euo pipefail

    # Instalar code-server (modo standalone)
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    # Instalar extensões no code-server (Claude Code)
    /tmp/code-server/bin/code-server --install-extension anthropic.claude-copilot || true

    # Iniciar code-server (sem auth; o acesso é protegido pelo Coder)
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

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle { ignore_changes = all }
}

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

resource "docker_container" "ws" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.img.name
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  # Garante que o agent respeite a access_url pública (evita 'localhost' hardcoded)
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  # Resolve host.docker.internal para host-gateway (Docker 20.10+)
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home.name
    read_only      = false
  }
}

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
