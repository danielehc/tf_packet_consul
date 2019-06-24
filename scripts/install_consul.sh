#!/usr/bin/env bash
set -x 

###################
# VARIABLES       #
###################

CONSUL_VERSION=${CONSUL_VERSION:-"1.5.1"}
CONSUL_TEMPLATE_VERSION=${CONSUL_TEMPLATE_VERSION:-"0.20.0"}
ENTERPRISE=${ENTERPRISE}
# Valid archs are
# darwin_386 darwin_amd64 
# freebsd_386 freebsd_amd64 
# linux_386 ${ARCH} linux_arm linux_arm64 
# solaris_amd64 
# windows_386 windows_amd64
ARCH=${ARCH:-"linux_arm"}

###################
# FUNCTIONS		  #
###################

create_service () {
  if [ ! -f /etc/systemd/system/${1}.service ]; then
    
    create_service_user ${1}
    
    sudo tee /etc/systemd/system/${1}.service <<EOF
	### BEGIN INIT INFO
	# Provides:          ${1}
	# Required-Start:    $local_fs $remote_fs
	# Required-Stop:     $local_fs $remote_fs
	# Default-Start:     2 3 4 5
	# Default-Stop:      0 1 6
	# Short-Description: ${1} agent
	# Description:       ${2}
	### END INIT INFO

	[Unit]
	Description=${2}
	Requires=network-online.target
	After=network-online.target

	[Service]
	User=${1}
	Group=${1}
	PIDFile=/var/run/${1}/${1}.pid
	PermissionsStartOnly=true
	ExecStartPre=-/bin/mkdir -p /var/run/${1}
	ExecStartPre=/bin/chown -R ${1}:${1} /var/run/${1}
	ExecStart=${3}
	ExecReload=/bin/kill -HUP ${MAINPID}
	KillMode=process
	KillSignal=SIGTERM
	Restart=on-failure
	RestartSec=42s
	StartLimitBurst=3
	LimitNOFILE=65536
	StandardOutput=syslog
	StandardError=syslog
	SyslogIdentifier=${1}

	[Install]
	WantedBy=multi-user.target
EOF

  	sudo systemctl daemon-reload

	# Configure rsyslog to export log lines referred to our service to ${LOG}
	sudo echo -e  "if "'$programname'" == '${1}' then ${LOG}\n& stop" > /etc/rsyslog.d/${1}.conf
	sudo systemctl restart rsyslog.service

  fi

}


create_service_user () {
  
  if ! grep ${1} /etc/passwd >/dev/null 2>&1; then
    echo "Creating ${1} user to run the ${1} service"
    sudo useradd --system --home /etc/${1}.d --shell /bin/false ${1}
    sudo mkdir --parents /opt/${1} /usr/local/${1} /etc/${1}.d
    sudo chown --recursive ${1}:${1} /opt/${1} /etc/${1}.d /usr/local/${1}
	# sudo useradd -u 1000 -o --system --home /etc/${1}.d --shell /bin/false ${1}
	# sudo usermod -a -G vagrant ${1}
  fi

}

###################
# PREREQUISITES   #
###################

# The VM should already have these tools but in case they are not 
# there we reinstall them
which unzip curl jq /sbin/route killall &>/dev/null || {
    echo "Installing dependencies ..."
    sudo apt-get update
    sudo apt-get install -y unzip curl jq net-tools dnsutils psmisc
    sudo apt-get clean
}

###################
# CONSUL INSTALL  #
###################

# If no consul binary we download one
which consul &>/dev/null || {
    echo "Determining Consul version to install ..."

	CHECKPOINT_URL="https://checkpoint-api.hashicorp.com/v1/check"
    if [ -z "$CONSUL_VERSION" ]; then
        CONSUL_VERSION=$(curl -s "${CHECKPOINT_URL}"/consul | jq .current_version | tr -d '"')
    fi
	
	pushd /tmp/
	PKG_NAME="/vagrant/pkg/consul_${CONSUL_VERSION}_${ARCH}.zip"
	
	if [ "$ENTERPRISE" = true ] ; then
    	# At the moment Consul enterprise can be instaled only from local folder
		echo "Installing Consul Enterprise $CONSUL_VERSION"
		if [ -f "/vagrant/pkg/consul-enterprise_${CONSUL_VERSION}+prem_${ARCH}.zip" ]; then
			echo "Found Consul in /vagrant/pkg"
			PKG_NAME="/vagrant/pkg/consul-enterprise_${CONSUL_VERSION}+prem_${ARCH}.zip"
    	else
			echo "Consul Enterprise $CONSUL_VERSION not found. ABORTING!!"
			exit 1
		fi
	elif [ -f "/vagrant/pkg/consul_${CONSUL_VERSION}_${ARCH}.zip" ]; then
			echo "Found Consul in /vagrant/pkg"
    else
		echo "Fetching Consul version ${CONSUL_VERSION} ..."
		mkdir -p /vagrant/pkg/
		curl -s https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_${ARCH}.zip -o /vagrant/pkg/consul_${CONSUL_VERSION}_${ARCH}.zip
	
		if [ $? -ne 0 ]; then
			echo "Download failed! Exiting."
			exit 1
		fi

	fi
    
    echo "Installing Consul version ${CONSUL_VERSION} ..."
	pushd /tmp
    unzip ${PKG_NAME} 
    sudo chmod +x consul
    sudo mv consul /usr/local/bin/consul

	# Check logs folders
	if [ -d /vagrant ]; then
		sudo mkdir -p /vagrant/logs
		chmod +w /vagrant/logs
		LOG="/vagrant/logs/consul_${HOSTNAME}.log"
	else
		LOG="/tmp/consul.log"
	fi

	[ -f ${LOG} ] && rm -rf ${LOG}

	# Create consul user and service
	create_service consul "HashiCorp's Distributed Service Mesh" "/usr/local/bin/consul agent -config-dir /etc/consul.d"
	
}

#############################
#  CONSUL TEMPLATE INSTALL  #
#############################

# If no consul-template binary we download one
which consul-template &> /dev/null || {

	echo "Determining Consul-template version to install ..."

	CHECKPOINT_URL="https://checkpoint-api.hashicorp.com/v1/check"
	if [ -z "$CONSUL_TEMPLATE_VERSION" ]; then
			CONSUL_TEMPLATE_VERSION=$(lynx --dump https://releases.hashicorp.com/consul-template/index.json | jq -r '.versions | to_entries[] | .value.version' | sort --version-sort | tail -1)
	fi
	
	echo $CONSUL_TEMPLATE_VERSION
	
	if [ -f "/vagrant/pkg/consul-template${CONSUL_TEMPLATE_VERSION}_${ARCH}.zip" ]; then
		echo "Found Consul-template in /vagrant/pkg"
  	else
		echo "Fetching Consul-template version ${CONSUL_TEMPLATE_VERSION} ..."
		mkdir -p /vagrant/pkg/
		curl -s https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_${ARCH}.zip -o /vagrant/pkg/consul-template${CONSUL_TEMPLATE_VERSION}_${ARCH}.zip
		
		if [ $? -ne 0 ]; then
			echo "Download failed! Exiting."
			exit 1
		fi
		
		# Copying the archive in the /vagrant folder to reuse it for future provisionings or other VMs

	fi
	
	echo "Installing Consul-template version ${CONSUL_TEMPLATE_VERSION} ..."
	pushd /tmp
    unzip /vagrant/pkg/consul-template${CONSUL_TEMPLATE_VERSION}_${ARCH}.zip
	sudo chmod +x consul-template
	sudo mv consul-template /usr/local/bin/consul-template
	
} 

# Check if Consul is installed
/usr/local/bin/consul --version

sudo systemctl start consul
set +x 
