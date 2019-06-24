#!/usr/bin/env bash

#set -x

###################
# VARIABLES		  #
###################

# Parameters required

# Consul Address
CONSUL_ADDRESS="http://127.0.0.1:8500"
CONSUL_DNS_ADDRESS="http://127.0.0.1:8600"

# Number of threads
THREAD_NUM=1

# Testfolder (randomize it?)
TEST_DIR="/tmp/consul/load_test"



# Check File location
TEST_FILE_DIR="file_checks"
LOG_FILE_DIR="logs"

# STOP THE WORLD file
# All trheard check for this file existence
# If file is removed the test stops
STW_FILE="stw.lock"

# Test scenario
# Available values: default service_reg watch_and_dns 
TEST_SCENARIO="default"


# When set, enables some additional debugging features. 
# Currently, this is only used to access runtime profiling HTTP endpoints.
DEV_MODE=${DEV_MODE:-true}

###################
# FUNCTIONS		  #
###################

generate_service_payload () {

	_SERV_NAME=$1
	_SERV_UID=$2

	# Generate generic service - this works for REST API
	sudo tee /tmp/payload.json <<EOF
{
    "ID": "${_SERV_NAME}-${_SERV_UID}",
    "name": "${_SERV_NAME}",
    "tags": [ "${_SERV_NAME}-${_SERV_UID}", "${_SERV_NAME}" ],
    "port": 8000,
    "check": {
        "args": [
            "sh",
            "-c",
            "if ! test -f /proc/$2/task/$3; then exit 2; else sleep 5; fi"
        ],
        "interval": "10s",
        "status": "passing"
    }
}

EOF

	cat /tmp/payload.json

}

register_consul_service() {
	echo "Test"
}


service_register_watch_update() {

	echo "Test"

}

generate_random_string() {
	# Check size as param otherwise defaults to 10
	KEY_SIZE=${1:-10}
	KEY_ALPH="a-z0-9"
	KEY_ROOT=`cat /dev/urandom | tr -dc \'${KEY_ALPH}\' | fold -w ${KEY_SIZE} | head -n 1`
	echo "$KEY_ROOT"
}

generate_random_num() {
	# Check size as param otherwise defaults to 10
	KEY_SIZE=${1:-10}
	KEY_ROOT=`cat /dev/urandom | tr -dc '0-9' | fold -w ${KEY_SIZE} | head -n 1`
	echo "$KEY_ROOT"
}

generate_random_service_type () {
	# Array with services
	SERVICE_NAMES=("web" "db" "redis" "vault" "ldap", "nginx", "mongo")

	# Seed random generator
	# RANDOM=$$$(date +%s)
	RANDOM=`generate_random_num 10`

	SERVICE_NAME=${SERVICE_NAMES[$RANDOM % ${#SERVICE_NAMES[@]} ]}

	echo ${SERVICE_NAME}
}

# Generates either 0 or 1
# if no parameter is passed they will be generated with 50% probability
# Otherwise 0 wil be generated with the probability passed as argument
generate_unbalanced_bool () {
	echo 0;
}

###################
# USE CASES		  #
###################

# These can be executed from the main body of the script with some tuning
# Ideally the use case is to be executed in background (with &) so to leave space for other threads


# 1. Around 200 processes with 1 thread each, communicating with consul (server) with service registration and watch.



uc_service_register_and_monitor() {
	
	# Generate random service name and type
	SERVICE_TYPE=`generate_random_service_type`
	SERVICE_ID=`generate_random_string 10`

	echo ${SERVICE_TYPE} - ${SERVICE_ID}

	generate_service_payload ${SERVICE_TYPE} ${SERVICE_ID}
	# Generate Service payload and check
		# SERVICE_NAME=
		# SERVICE_PORT=
		# CHECK_FILENAME=

	# Register the service

	# Iterate on a watch for service name
		# If service is unhealthy: 
			# regenerate state file (to make it healty) and wait until gets healthy
			# modify service to add tag recovered

		# If service is healty: 
			# randomly tamper another service by removing the state file (to make it unhealty)
			# modify service to remove tag recovered
		
		# Sleep some time random between 1 and 5 sec
}

# 2. Three processes with 100 threads each, fetching /watching services in same consul server.

uc_service_watch_and_query() {

	echo "Test"
	# Get list of services
	
	# Pick random service
	
	# Iterate on a watch for service type (using tags)

		# Monitor number of services available
		
		# If changed from last time write in logs
	
		# Query the service (generate some load on the DNS interface)

		# If unhealty, write in logs and wait until gets healthy

		# Sleep some time random between 1 and 5 sec

}

#########################
# CONSUL LOAD GENERATOR #
#########################

# Check parameters

POSITIONAL=()

if [ $# -eq 0 ]
  then
    echo "No arguments supplied - please supply at least ticket number (with -t) and customer name (with -c)"
    exit
fi

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    	echo "Syntetic Consul Load Generator"
		echo "Usage:"
    	shift # past argument
    	exit
    ;;
	-s|--scenario)
    	TEST_SCENARIO="$2"
    	shift # past argument
    	shift # past value
    ;;
	-t|--thread)
    	THREAD_NUM="$2"
    	shift # past argument
    	shift # past value
    ;;
    *)    # unknown option
    	POSITIONAL+=("$1") # save it in an array for later
    	shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters


# Test bench for functions
set +x
for i in `seq -w 1 $1`; do
    #echo $i
    
	uc_service_register_and_monitor

    #sleep 1
done
set -x



# For example, total load on consul server is point 1+ point 2 as below:
# 1. Around 200 processes with 1 thread each, communicating with consul (server) with service registration and watch.
# 2. Three processes with 100 threads each, fetching /watching services in same consul server.

# Generate random id for test
#TEST_ID=""

# Check if test_id exists otherwise creates folders for it

# Generate lock

# Iterate on lock

	# While lockfile exists

	# Select scenario 

	# Scenario 1 - Service registration checks and random disturbance

		# Execute for number of threads

		# Create service if does not exist

		# Watch 

	# Scenario 2


# if [] scenario equals service_reg

# for i in `seq -w 1 $SERVICE_NUM`; do
#     echo $i
#     # generate_services_config_test_pid $i $cPID $cTID
#     generate_sh_check $i $cPID $cTID
#     curl --request PUT --data @/tmp/payload.json http://127.0.0.1:8500/v1/agent/service/register

#     curl -s http://127.0.0.1:8500/v1/health/state/critical | jq -r '.[] | "\(.ServiceName)  \(.Status)"'

#     sleep 1
# done

# Register a service and check
	# Generate service payload
		# SERVICE_NAME=
		# SERVICE_PORT=
		# CHECK_FILENAME=

	# Register Service in Consul

# Watch services for change

	# Check watch for services

	# If service changes do something



# If service is red, change file and update service




# Scenario 2

# Check for service x using watch
# If service is available do a dig






#set +x