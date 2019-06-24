output "public_ip1" {
  value = "${packet_device.consul_server.0.access_public_ipv4}"
}

output "where_to_curl1" {
  value = "${format("curl -sL %s", packet_device.consul_server.0.access_public_ipv4)}"
}

output "where_to_ssh1" {
  value = "${format("ssh -i priv/id_rsa root@%s", packet_device.consul_server.0.access_public_ipv4)}"
}

# output "public_ip2" {
#   value = "${packet_device.consul2.access_public_ipv4}"
# }

# output "where_to_curl2" {
#   value = "${format("curl -sL %s", packet_device.consul2.access_public_ipv4)}"
# }

# output "where_to_ssh2" {
#   value = "${format("ssh -i priv/id_rsa root@%s", packet_device.consul2.access_public_ipv4)}"
# }

# output "public_ip3" {
#   value = "${packet_device.consul3.access_public_ipv4}"
# }

# output "where_to_curl3" {
#   value = "${format("curl -sL %s", packet_device.consul3.access_public_ipv4)}"
# }

# output "where_to_ssh3" {
#   value = "${format("ssh -i priv/id_rsa root@%s", packet_device.consul3.access_public_ipv4)}"
# }