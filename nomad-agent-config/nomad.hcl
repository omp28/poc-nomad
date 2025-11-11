# ~/nomad-agent-config/nomad.hcl

data_dir  = "/tmp/nomad"
bind_addr = "0.0.0.0"

# Enable single-node cluster (server + client)
server {
  enabled          = true
  bootstrap_expect = 1
}

client {
  enabled = true

  # Tag this node (optional but useful for identification)
  node_class = "elastic-poc"

  # Enable Docker driver support
  options = {
    "driver.raw_exec.enable" = "1"
    "driver.docker.enable"   = "1"
    "network.cni_path"       = "/opt/cni/bin"
  }
  # register loopback as a named host network
  host_network "loopback" {
    interface = "lo"
  }
}

