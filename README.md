
# Base Consul Cluster on Packet.net

Generatea an arm64 cluster in Packet.net and installs Consul 1.5.1 amr32 on it.

## vars

```
export token="<the_packet_token>"
export TF_VAR_token=$token

export projectid=<the_project_id>
export TF_VAR_projectid=$projectid

export prefix=daniele
export TF_VAR_prefix=$prefix
```

By default it tries to create 3 server and 3 clients.

It is possible to tune this by using `server_count` and `client_count` variables:

```
export server_count="desired amount of nodes"
export TF_VAR_server_count=$server_count

export client_count="desired amount of nodes"
export TF_VAR_client_count=$client_count
```

## run

```
terraform fmt

terraform init

terraform plan

terraform apply
```

## Info

Sometimes Packet.net does not have enough available resources to spin up 6 nodes so it spins olny a subset of them (usually 4 or 5). 

In that case it will throw the following errror:
```
vagrant@tf-cli:/vagrant/labs/tf_packet$ terraform apply -auto-approve
packet_ssh_key.key1: Refreshing state... [id=...]
packet_device.consul_server[1]: Refreshing state... [id=...]
packet_device.consul_server[2]: Refreshing state... [id=...]
packet_device.consul_client[2]: Refreshing state... [id=...]
packet_device.consul_client[1]: Refreshing state... [id=...]
packet_device.consul_client[0]: Creating...
packet_device.consul_server[0]: Creating...

Error: The facility ewr1 has no provisionable c2.large.arm servers matching your criteria

  on main.tf line 11, in resource "packet_device" "consul_server":
  11: resource "packet_device" "consul_server" {



Error: The facility ewr1 has no provisionable c2.large.arm servers matching your criteria

  on main.tf line 76, in resource "packet_device" "consul_client":
  76: resource "packet_device" "consul_client" {

```

Often after a few minutes resource become available so running again:

```
terraform plan

terraform apply
```

will generate the missing resources.