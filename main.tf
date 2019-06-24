# Configure the Packet Provider
provider "packet" {
  auth_token = "${var.token}"
}

resource "packet_ssh_key" "key1" {
  name       = "terraform-1"
  public_key = "${file("/vagrant/labs/tf_packet/priv/id_rsa.pub")}"
}

resource "packet_device" "consul_server" {
  count            = "${var.server_count}" 
  hostname         = "${var.prefix}-consul-server-${count.index}"
  plan             = "${var.plan_arm}"
  facilities       = ["${var.facility}"]
  operating_system = "${var.operating_system}"
  billing_cycle    = "hourly"
  project_id       = "${var.projectid}"
  tags             = ["${var.prefix}"]
  depends_on       = ["packet_ssh_key.key1"]

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${self.access_public_ipv4}"
    private_key = "${file("/vagrant/labs/tf_packet/priv/id_rsa")}"
  }

  # in case we need the root password
  provisioner "file" {
    content     = "root/${self.root_password}"
    destination = "/root/roowpw.txt"
  }

  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/scripts/provision.sh"
    destination = "/tmp/provision.sh"
  }

  #Generate Consul config files locally
  provisioner "local-exec" {
    command = "bash scripts/local_generate_consul_config.sh"

    environment = {
      NODENAME       = "${self.hostname}"
      AGENT_ROLE     = "server"
      PACKET_TOKEN   = "${var.token}"
      PACKET_PROJECT = "${var.projectid}"
      IP_ADDRESS     = "${self.access_public_ipv4}"
      LAB_DOMAIN     = "consul"
      LAB_DC         = "dc1"
      SERVER_COUNT   = "${var.server_count}"
    }
  }

  # Provision Config folder
  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/tmp/${self.hostname}/consul.d"
    destination = "/etc"
  }

  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/scripts/install_consul.sh"
    destination = "/tmp/install_consul.sh"
  }

  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/scripts/test_generate_consul_traffic.sh"
    destination = "/tmp/test_generate_consul_traffic.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      "bash ./provision.sh",
      "bash ./install_consul.sh",
    ]
  }
}

resource "packet_device" "consul_client" {
  count            = "${var.client_count}" 
  hostname         = "${var.prefix}-consul-client-${count.index}"
  plan             = "${var.plan_arm}"
  facilities       = ["${var.facility}"]
  operating_system = "${var.operating_system}"
  billing_cycle    = "hourly"
  project_id       = "${var.projectid}"
  tags             = ["${var.prefix}"]
  # depends_on       = ["packet_ssh_key.key1", "packet_device.consul_server"]
  depends_on       = ["packet_ssh_key.key1"]
  

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${self.access_public_ipv4}"
    private_key = "${file("/vagrant/labs/tf_packet/priv/id_rsa")}"
  }

  # in case we need the root password
  provisioner "file" {
    content     = "root/${self.root_password}"
    destination = "/root/roowpw.txt"
  }

  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/scripts/provision.sh"
    destination = "/tmp/provision.sh"
  }

  #Generate Consul config files locally
  provisioner "local-exec" {
    command = "bash scripts/local_generate_consul_config.sh"

    environment = {
      NODENAME       = "${self.hostname}"
      AGENT_ROLE     = "client"
      PACKET_TOKEN   = "${var.token}"
      PACKET_PROJECT = "${var.projectid}"
      IP_ADDRESS     = "${self.access_public_ipv4}"
      LAB_DOMAIN     = "consul"
      LAB_DC         = "dc1"
      SERVER_COUNT   = "${var.server_count}"
    }
  }

  # Provision Config folder
  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/tmp/${self.hostname}/consul.d"
    destination = "/etc"
  }

  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/scripts/install_consul.sh"
    destination = "/tmp/install_consul.sh"
  }

  provisioner "file" {
    source      = "/vagrant/labs/tf_packet/scripts/test_generate_consul_traffic.sh"
    destination = "/tmp/test_generate_consul_traffic.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      "bash ./provision.sh",
      "bash ./install_consul.sh",
    ]
  }
}

