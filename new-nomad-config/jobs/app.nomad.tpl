job "app-{{BRANCH}}" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1

    # Bind this service's HTTP port to localhost (loopback)
    network {
      mode = "bridge"
      port "http" {
        static       = {{PORT}}
        to           = 3000
      }
    }

    service {
      name = "app-{{BRANCH}}"
      port = "http"
      tags = [
        "branch={{BRANCH}}",
        "base-path={{BASE_PATH}}"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
	address_mode  = "host"
      }
    }

    task "app" {
      driver = "docker"

      config {
        image       = "app1:{{BRANCH}}"
        ports       = ["http"]
        force_pull  = false
      }

      env {
        VITE_BASE_PATH = "{{BASE_PATH}}"
        NODE_ENV       = "production"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }
  }
}
