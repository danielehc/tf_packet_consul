mkdir -p /etc/dpkg/dpkg.cfg.d
cat >/etc/dpkg/dpkg.cfg.d/01_nodoc <<EOF
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF

export DEBIAN_FRONTEND=noninteractive
export APTARGS="-qq -o=Dpkg::Use-Pty=0"

apt-get clean ${APTARGS}
apt-get update ${APTARGS}

apt-get upgrade -y ${APTARGS}
apt-get dist-upgrade -y ${APTARGS}

# Update to the latest kernel
apt-get install -y linux-generic linux-image-generic ${APTARGS}

# # build-essential
# apt-get install -y build-essential ${APTARGS}

# # ruby
# apt-get install -y ruby ruby-dev ${APTARGS}

# # inspec
# gem install inspec

# # pip
# apt-get install -y python-pip ${APTARGS}
# apt-get install -y python3-pip ${APTARGS}

# git
apt-get install -y git ${APTARGS}

# jq
apt-get install -y jq ${APTARGS}

# curl
apt-get install -y curl ${APTARGS}

# wget
apt-get install -y wget ${APTARGS}

# dig
apt-get install -y dig ${APTARGS}

# Configure Machine for Core dumps
# https://pve.proxmox.com/wiki/Enable_Core_Dump_systemd

sudo tee /etc/security/limits.d/core.conf <<EOF
root       hard        core        unlimited
root       soft        core        unlimited
consul       hard        core        unlimited
consul       soft        core        unlimited
EOF

echo "DefaultLimitCORE=infinity" >> /etc/systemd/system.conf

sudo tee  /etc/sysctl.d/core.conf <<EOF
kernel.core_pattern = /var/lib/coredumps/core-%e-sig%s-user%u-group%g-pid%p-time%t
kernel.core_uses_pid = 1
fs.suid_dumpable = 2
EOF

systemctl daemon-reexec

# Hide Ubuntu splash screen during OS Boot, so you can see if the boot hangs
# apt-get remove -y plymouth-theme-ubuntu-text
# sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
# update-grub



# Reboot with the new kernel
# shutdown -r now
