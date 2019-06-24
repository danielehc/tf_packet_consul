#!/usr/bin/env bash

set -x

###################
# VARIABLES		  #
###################

# Parameters required
# NODENAME 			- Name of the remote resource 
# AGENT_ROLE 		- server | client
# PACKET_TOKEN 		- Token for Packet Auto Join
# PACKET_PROJECT 	- UUID for the Packet project for Auto Join
# IP_ADDRESS 		- Node Public IP address
# LAB_DOMAIN 		- Domain to be used for the cluster
# LAB_DC 			- DC to be used for the cluster
# SERVER_COUNT		= Number of server used for bootstrapt_expect

NODENAME=${NODENAME}
AGENT_ROLE=${AGENT_ROLE}

PACKET_TOKEN=${PACKET_TOKEN}
PACKET_PROJECT=${PACKET_PROJECT}

IP_ADDRESS=${IP_ADDRESS}

LAB_DOMAIN=${LAB_DOMAIN}
LAB_DC=${LAB_DC}

SERVER_COUNT=${SERVER_COUNT:-1}


# When set, enables some additional debugging features. 
# Currently, this is only used to access runtime profiling HTTP endpoints.
DEV_MODE=${DEV_MODE:-true}

###################
# FUNCTIONS		  #
###################

generate_consul_server_config () {

	# To test with snapshot we need to lower the threshold
	#EXTRA_CONFIG="\"raft_snapshot_threshold\": 100,"

	sudo tee ${CONFIG_FOLDER}/consul_server_setup.json <<EOF
	{
		"server": true,
		${EXTRA_CONFIG}
		"bootstrap_expect": ${SERVER_COUNT}
	}
EOF
}

# Accepts as parameter the role of the agent
# Valid values are 'server' and 'client'
# Input is not sanitized
generate_consul_config () {

	# Generate server-only configuration
	if [ $1 == "server" ]; then
		generate_consul_server_config
	fi

	# Packet Auto Join
	JOIN_STRING="\"retry_join\": [\"provider=packet auth_token=${PACKET_TOKEN} project=${PACKET_PROJECT} address_type=public_v4\"]"

	# # Based on the IP we generate a join string for the other servers in the same DC 
	# JOIN_STRING=""
	# for i in `seq 1 $SERVER_COUNT`; do
	# 	[ "${JOIN_STRING}" ] && JOIN_STRING="${JOIN_STRING}, "
	# 	JOIN_STRING="$JOIN_STRING""\"$DC_RANGE.$((10 + i))\""
	# done
	# JOIN_STRING="[ ${JOIN_STRING} ]"

	# Generate agent configuration
	sudo tee ${CONFIG_FOLDER}/consul_agent_setup.json <<EOF
	{
		"datacenter": "${LAB_DC}",
		"domain": "${LAB_DOMAIN}",
		"data_dir": "/usr/local/consul",
		"enable_script_checks" : true,
		"enable_debug" : ${DEV_MODE},
		"ui": true,
		"client_addr": "0.0.0.0",
		"bind_addr": "${IP_ADDRESS}",
		${JOIN_STRING},
		"log_level": "TRACE",
		"node_name": "${NODENAME}",
		"server_name": "${NODENAME}.${LAB_DC}.${LAB_DOMAIN}"
	}
EOF
}

########################
# CONSUL CONFIGURATION #
########################

# Parameters required
# NODENAME 			- Name of the remote resource 
# AGENT_ROLE 		- server | client
# PACKET_TOKEN 		- Token for Packet Auto Join
# PACKET_PROJECT 	- UUID for the Packet project for Auto Join
# IP_ADDRESS 		- Node Public IP address
# LAB_DOMAIN 		- Domain to be used for the cluster
# LAB_DC 			- DC to be used for the cluster
# SERVER_COUNT		= Number of server used for bootstrapt_expect


echo "Configure node ${NODENAME} as ${AGENT_ROLE}"

CONFIG_FOLDER="/vagrant/labs/tf_packet/tmp/${NODENAME}/consul.d"

# Delete folder /vagrant/tmp/<nodename>/consul.d
sudo rm -rf ${CONFIG_FOLDER}

# Create folder /vagrant/tmp/<nodename>/consul.d
sudo mkdir -p ${CONFIG_FOLDER}

# Generate config file for agent
generate_consul_config ${AGENT_ROLE}




set +x