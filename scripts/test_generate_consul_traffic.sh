#!/usr/bin/env bash

#set -x

###################
# VARIABLES		  #
###################

# Parameters required

# Consul Address
CONSUL_ADDRESS="http://127.0.0.1:8500"
CONSUL_DNS_IP="127.0.0.1"
CONSUL_DNS_PORT="8600"

# Number of threads
THREAD_NUM=0

# Testfolder (randomize it?)
TEST_DIR="/tmp/consul/load_test"

# Scripts dir
SCRIPT_DIR="/tmp"

# STOP THE WORLD file
# All trheard check for this file existence
# If file is removed the test stops
STW_FILE="stw.lock"

# Test scenario
# Available values: default service_reg watch_and_dns 
RUN_SCENARIO="default"

# Flush after run
FLUSH_AFTER="false"

# When set, enables some additional debugging features. 
# Currently, this is only used to access runtime profiling HTTP endpoints.
DEV_MODE=${DEV_MODE:-true}

###################
# FUNCTIONS		  #
###################
# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "** Trapped CTRL-C"
		rm -rf ${LOCK_FILE}
}

echo_t () {
	echo `date '+%Y-%m-%d_%H%M%S'`" $@"
}


generate_service_payload () {

	_SERV_NAME=$1
	_SERV_UID=$2
	_SERV_LOCK_FILE=$3
	_T_NUM=$4
	_SERV_FILE=$5

	echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Generating service definition at ${_SERV_FILE}"

	# Generate generic service - this works for REST API
	sudo tee ${_SERV_FILE} <<EOF
{
    "ID": "${_SERV_NAME}-${_SERV_UID}",
    "name": "${_SERV_NAME}",
    "tags": [ "${_SERV_NAME}-${_SERV_UID}", "${_SERV_NAME}", "${_SERV_UID}", "${_T_NUM}"  ],
    "port": 8000,
    "check": {
        "args": [
            "sh",
            "-c",
            "if ! test -f ${_SERV_LOCK_FILE}; then exit 2; else sleep 5; fi"
        ],
        "interval": "10s",
        "status": "passing"
    }
}

EOF

	# cat /tmp/payload.json

}

generate_watch_payload() {
	echo "Test"
}

register_consul_service() {
	echo "Test"
}

generate_random_string() {
	# Check size as param otherwise defaults to 10
	KEY_SIZE=${1:-10}
	KEY_ALPH="a-z0-9"
	KEY_ROOT=`cat /dev/urandom | tr -dc ${KEY_ALPH} | fold -w ${KEY_SIZE} | head -n 1`
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
	SERVICE_NAMES=("web" "db" "redis" "vault" "ldap" "nginx" "mongo")

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
# Every instance of the UC will:
# * Create a service definition and register the service with check
# * Iterate until the main test is still running (using  ${LOCK_FILE})
# 	* IF the service is healthy > pick a random service and make it unhealthy (by removing the Service lock file)
# 	* IF the service is un-healthy > fix it (by adding the Service lock file back)
# 	* [TODO] Add a tag to the service changed
# 	* If lock files are too few, restores all lock files.

uc_service_register_and_monitor() {
	
	T_NUM="$1"
	
	echo_t "[ ${T_NUM} ] Check lock file"

	# If lock file doesn't exist we exit
	if [ ! -e ${LOCK_FILE} ]; then

		echo_t "[ ${T_NUM} ] Lock file ${LOCK_FILE} not found. Exiting."
		return 2

	fi
	
	# Generate random service id, type and name
	SERVICE_ID=`generate_random_string 5`
	SERVICE_TYPE=`generate_random_service_type`
	SERVICE_NAME="${SERVICE_TYPE}-${SERVICE_ID}"

	echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Generating service definition." 

	# Generate folders and files
	SERVICE_FOLDER="${CURRENT_SCENARIO_FILE_DIR}/${SERVICE_NAME}"
	SERVICE_LOCK_FILE="${SERVICE_FOLDER}/${SERVICE_NAME}.lock"

	if  [ ! -d "${SERVICE_FOLDER}" ]; then

		echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service folder $SERVICE_FOLDER does not exist...creating it!"

		mkdir -p ${SERVICE_FOLDER}
		touch ${SERVICE_LOCK_FILE}

	fi 

	if [ ! -d ${SERVICE_FOLDER} ]; then
		SERVICE_FILE="/tmp/payload.json"
	else
		SERVICE_FILE="${SERVICE_FOLDER}/payload.json"
	fi

	generate_service_payload ${SERVICE_TYPE} ${SERVICE_ID} ${SERVICE_LOCK_FILE} ${THREAD_NUM} ${SERVICE_FILE}

	# Register the service
	echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service registration."
	curl --request PUT --data @${SERVICE_FILE} ${CONSUL_ADDRESS}/v1/agent/service/register

	if [ $? -ne 0 ]; then
		echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service registration failed! Exiting."
		return 1
	fi

	# Iterate on lock
	while [ -f ${LOCK_FILE} ]; do
		
		# Check if service is healthy
		echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Lock file is still there."
		sleep 5

		# Check OWN state
		# curl -s http://127.0.0.1:8500/v1/health/state/critical | jq -r '.[] | "\(.ServiceName)  \(.Status)"'
		# curl --request GET http://127.0.0.1:8500/v1/health/service/web?tag=web-iypa9 | jq

		# curl -s --data-urlencode 'filter=ServiceID == web-iypa9' --request GET http://127.0.0.1:8500/v1/health/checks/web  | jq
		# curl --request GET http://127.0.0.1:8500/v1/health/service/web --data-urlencode 'filter=Checks.ServiceID == "web-iypa9"' | jq

		# curl --request GET http://127.0.0.1:8500/v1/health/state/passing --data-urlencode 'filter=ServiceID == web-iypa9' | jq

		_STATUS=`curl -s --request GET ${CONSUL_ADDRESS}/v1/health/checks/${SERVICE_TYPE} | jq -r '.[] | select(.ServiceID=="'${SERVICE_NAME}'") | .Status'`

		if [ ${_STATUS} == "passing" ]; then
			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Status: ${_STATUS}"

			# randomly tamper another service by removing the state file (to make it unhealty)
			_TAMP_LOCK=`find ${CURRENT_SCENARIO_FILE_DIR} -name "*.lock" | grep -v ${SERVICE_NAME} | sort -R | head -1`

			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Removing: ${_TAMP_LOCK}"

			rm -rf ${_TAMP_LOCK}

		elif [ ${_STATUS} == "critical" ]; then
			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Status: ${_STATUS}"

			# regenerate state file (to make it healty) and wait until gets healthy
			_TAMP_LOCK="${CURRENT_SCENARIO_FILE_DIR}/${SERVICE_NAME}/${SERVICE_NAME}.lock"
			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Restoring: ${_TAMP_LOCK}"

			touch "${_TAMP_LOCK}"

			while [ ${_STATUS} != "passing" ]; do

				_STATUS=`curl -s --request GET ${CONSUL_ADDRESS}/v1/health/checks/${SERVICE_TYPE} | jq -r '.[] | select(.ServiceID=="'${SERVICE_NAME}'") | .Status'` 
				sleep 1
			done

			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service is now in good state."

		else
			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service is in unknown state"
		fi

		sleep 10

		# Checks number of locks left and if less than ${THREAD_NUM}/10 restores all locks

		_REMAIN_LOCKS=`find ${CURRENT_SCENARIO_FILE_DIR} -name "*.lock" | wc -l`

		if [ ! ${_REMAIN_LOCKS} -gt $(( THREAD_NUM / 3 ))  ]; then
			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Only ${_REMAIN_LOCKS} locks left. Restoring."
			for i in `ls -1 ${CURRENT_SCENARIO_FILE_DIR}`; do touch ${CURRENT_SCENARIO_FILE_DIR}/$i/$i.lock; done
		fi
	done	

	echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] THREAD TERMINATED!!"
}


# 2. Three processes with 100 threads each, fetching /watching services in same consul server.
# Every instance of the UC will:
# * Pick a random service to watch for
# * Iterate until the main test is still running (using  ${LOCK_FILE})
# 	* 

uc_service_watch_and_query() {

	T_NUM="$1"
	
	echo_t "[ ${T_NUM} ] Check lock file"

	# If lock file doesn't exist we exit
	if [ ! -e ${LOCK_FILE} ]; then

		echo_t "[ ${T_NUM} ] Lock file ${LOCK_FILE} not found. Exiting."
		return 2

	fi

	# set -x 
	SERVICE_TYPE=`generate_random_service_type`

	# curl  -s --request GET ${CONSUL_ADDRESS}/v1/catalog/services
	# Pick random service
	
	# curl  -s --request GET http://127.0.0.1:8500/v1/catalog/service/redis | jq -r '.[] | .ServiceID' | sort -R | head -1

	SERVICE_NAME=`curl  -s --request GET ${CONSUL_ADDRESS}/v1/catalog/service/${SERVICE_TYPE} | jq -r '.[] | .ServiceID' | sort -R | head -1`

	

	while [ "${SERVICE_NAME}" == "" ]; do
		SERVICE_TYPE=`generate_random_service_type`
		SERVICE_NAME=`curl  -s --request GET ${CONSUL_ADDRESS}/v1/catalog/service/${SERVICE_TYPE} | jq -r '.[] | .ServiceID' | sort -R | head -1`
		sleep 1
	done

	# set +x
	echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service to watch is ${SERVICE_NAME}."

	# Watch and log in background
	# consul watch -type=keyprefix -prefix=foo/ /provision/scripts/test_watch_generic_handler.sh /tmp/file.log &

	# consul watch -type=service -service=ldap -tag=ldap-wt88o | jq -r '.[] | .Checks[] | select(.ServiceID == "ldap-wt88o") | .Status'

	# Iterate on lock
	while [ -f ${LOCK_FILE} ]; do

		# set -x 
		_STATUS=`consul watch -type=service -service=${SERVICE_TYPE} -tag=${SERVICE_NAME} | jq -r '.[] | .Checks[] | select(.ServiceID == "'${SERVICE_NAME}'") | .Status'`

		# set +x 
		while [ ${_STATUS} != "passing" ]; do

			echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service is still unhealty"
			sleep 5
			
			_STATUS=`consul watch -type=service -service=${SERVICE_TYPE} -tag=${SERVICE_NAME} | jq -r '.[] | .Checks[] | select(.ServiceID == "'${SERVICE_NAME}'") | .Status'` 
		done

		_SERV_IP=`dig @${CONSUL_DNS_IP} -p ${CONSUL_DNS_PORT} +short ${SERVICE_NAME}.${SERVICE_TYPE}.service.consul`

		echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] Service IP is ${_SERV_IP}."

		sleep 5

	done

	echo_t "[ ${T_NUM} ][ ${SERVICE_NAME} ] THREAD TERMINATED!!"

}

# The principle of what it does is to register a couple of services, sleep couple of seconds
# deregister the services and sleeps a couple of seconds. This is done in an eternal loop.
# And forked off 9 times , creating 2*2*2*2*2*2*2*2*2 number of processes - all executing
# this eternal loop in parallell.

uc_service_register_and_deregister () {

	return 1;

}


#########################
# CONSUL LOAD GENERATOR #
#########################



# Check parameters
# ----------------

POSITIONAL=()

if [ $# -eq 0 ]
  then
    echo "No arguments supplied - please supply at least scenario (with -s) and thread number (with -t)"
	echo "Valid scenario names are \`service_creation\` and \`service_monitoring\`"
    exit 1
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
	-f|--flush)
    	FLUSH_AFTER="true"
    	shift # past argument
	;;
	-s|--scenario)
    	RUN_SCENARIO="$2"
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

# Generate scenario and test data
# -------------------------------

# Generate random id for test
SCENARIO_ID=`generate_random_string 10`
echo_t "SCENARIO ID: ${SCENARIO_ID}"

# Check if scenario_id exists otherwise creates folders for it
CURRENT_SCENARIO_ROOT="${TEST_DIR}/"`date '+%Y-%m-%d_%H%M%S'`"_${SCENARIO_ID}"
CURRENT_SCENARIO_FILE_DIR="${CURRENT_SCENARIO_ROOT}/services_config"
CURRENT_SCENARIO_LOG_DIR="${CURRENT_SCENARIO_ROOT}/logs"

LOCK_FILE="${CURRENT_SCENARIO_ROOT}/lock"

if [ ! -d "${CURRENT_SCENARIO_ROOT}" ]; then
set -x
	echo_t "Test folder $CURRENT_SCENARIO_ROOT does not exist...creating it!"

	mkdir -p ${CURRENT_SCENARIO_ROOT}
	mkdir -p ${CURRENT_SCENARIO_FILE_DIR}
	mkdir -p ${CURRENT_SCENARIO_LOG_DIR}
	touch ${LOCK_FILE}
set +x
fi

# Checking if number of threads is a number and is greather than 0
if  ! [[ "${THREAD_NUM}" =~ ^[0-9]+$ ]] || [ ! ${THREAD_NUM} -gt 0 ]; then
	echo_t "Please enter a number of thread greather than zero."
	exit 1
fi

# Check scenarios

# For example:
# 1. Around 200 processes with 1 thread each, communicating with consul (server) with service registration and watch.
# 2. Three processes with 100 threads each, fetching /watching services in same consul server.
# 3. Register a couple of services, sleep couple of seconds deregister the services and sleeps a couple of seconds. 
# 		This is done in an eternal loop. 
# 		And forked off 9 times , creating 2*2*2*2*2*2*2*2*2 number of processes
#		all executing # this eternal loop in parallell.


# |
# | SCENARIO: SERVICE CREATION
# | Example:  /provision/scripts/test_generate_consul_traffic.sh -f -t 10 -s service_creation
# |
# | ${THREAD_NUM} processes registering services, randomly making services health fail and recover, tagging services
# |
# | Note: The function seems to converge to a point where no lock file is present anymore
# | 		It might need to implement some form of lock restoring.
if [ "${RUN_SCENARIO}" == "service_creation" ] ; then 
	# This scenario will create services, monitor health state and randomly generate outages
	echo "Generating services"

	for i in `seq -w 1 ${THREAD_NUM}`; do
    
		#echo Generating $i
    
		uc_service_register_and_monitor $i & 

		#sleep 1
	done

# |
# | SCENARIO: SERVICE MONITORING
# | Example:  /provision/scripts/test_generate_consul_traffic.sh -f -t 10 -s service_monitoring
# |
elif [ "${RUN_SCENARIO}" == "service_monitoring" ] ; then 
	# This scenario will watch services (picking a randon one every thread) and execute a small script at every change reported
	# Also the watch script will query the service using `dig` to use Consul dns
	echo "Watching Services"
	
	for i in `seq -w 1 ${THREAD_NUM}`; do
    
		# echo Monitoring $i
    
		uc_service_watch_and_query $i &

		#sleep 1
	done

else
	echo "No scenario...bye"
fi


# Iterate on lock
while [ -f ${LOCK_FILE} ]; do
	sleep 1;
done

echo_t "${SCENARIO_ID} Lock file ${LOCK_FILE} not found...exiting."

if [ "${FLUSH_AFTER}" = true ]; then
	echo_t "${SCENARIO_ID} EXECUTION COMPLETE! Removing scenario files and logs"

	# remove files
	rm -rf ${CURRENT_SCENARIO_ROOT}
else
		echo_t "${SCENARIO_ID} EXECUTION COMPLETE! Scenario files and logs are available at ${CURRENT_SCENARIO_ROOT}"
fi

# Deregister all services
# for i in `curl  -s --request GET http://127.0.0.1:8500/v1/catalog/services | jq . | grep - | tr -d '"' | tr -d ','`; do consul services deregister -id=$i; sleep 1; done

# Restore locks (and service health)
# cd `find /tmp/consul/load_test -maxdepth 1 | sort -r | head -1`/services_config
# for i in `ls -1`; do touch ./$i/$i.lock; done