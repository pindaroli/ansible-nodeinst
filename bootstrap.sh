#!/bin/bash -uxe
# A bash script that prepares the OS
# before running the Ansible playbook

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Quit on error
set -e

# Detect OS
if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
  if [[ "$os_version" -lt 2004 ]]; then
      echo "Ubuntu 20.04 or higher is required to use this installer."
      echo "This version of Ubuntu is too old and unsupported."
      exit
    fi
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
  if [[ "$os_version" -lt 11 ]]; then
      echo "Debian 11 or higher is required to use this installer."
      echo "This version of Debian is too old and unsupported."
      exit
  fi
elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
  if [[ "$os_version" -lt 8 ]]; then
      echo "Rocky Linux 8 or higher is required to use this installer."
      echo "This version of Rocky/CentOS is too old and unsupported."
      exit
  fi
fi

check_root() {
# Check if the user is root or not
if [[ $EUID -ne 0 ]]; then
  if [[ ! -z "$1" ]]; then
    SUDO='sudo -E -H'
  else
    SUDO='sudo -E'
  fi
else
  SUDO=''
fi
}

install_dependencies_debian() {
  REQUIRED_PACKAGES=(
    sudo
    software-properties-common
    dnsutils
    curl
    git
    locales
    rsync
    apparmor
    python3
    python3-setuptools
    python3-apt
    python3-venv
    python3-pip
    aptitude
    direnv
    iptables
  )

  REQUIRED_PACKAGES_ARM64=(
    gcc
    python3-dev
    libffi-dev
    libssl-dev
    make
  )

  check_root
  # Disable interactive apt functionality
  export DEBIAN_FRONTEND=noninteractive
  # Update apt database, update all packages and install Ansible + dependencies
  $SUDO apt update -y;
  yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy dist-upgrade;
  yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy install "${REQUIRED_PACKAGES[@]}"
  yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy autoremove;
  [ $(uname -m) == "aarch64" ] && yes | $SUDO apt install -fuy "${REQUIRED_PACKAGES_ARM64[@]}"
  export DEBIAN_FRONTEND=
}

install_dependencies_centos() {
  check_root
  REQUIRED_PACKAGES=(
    sudo
    bind-utils
    curl
    git
    rsync
    https://kojipkgs.fedoraproject.org//vol/fedora_koji_archive02/packages/direnv/2.12.2/1.fc28/x86_64/direnv-2.12.2-1.fc28.x86_64.rpm
  )
  if [[ "$os_version" -eq 9 ]]; then
    REQUIRED_PACKAGES+=(
      python3
      python3-setuptools
      python3-pip
      python3-firewall
    )
  else 
    REQUIRED_PACKAGES+=(
      python39
      python39-setuptools
      python39-pip
      python3-firewall
      kmod-wireguard
      https://ftp.gwdg.de/pub/linux/elrepo/elrepo/el8/x86_64/RPMS/kmod-wireguard-1.0.20220627-4.el8_7.elrepo.x86_64.rpm
    )
  fi
  $SUDO dnf update -y
  $SUDO dnf install -y epel-release
  $SUDO dnf install -y "${REQUIRED_PACKAGES[@]}"
}

# Install all the dependencies
if [[ "$os" == "debian" || "$os" == "ubuntu" ]]; then
  install_dependencies_debian
elif [[ "$os" == "centos" ]]; then
  install_dependencies_centos
fi


# Set up a Python venv
set +e
if which python3.9; then
  PYTHON=$(which python3.9)
else
  PYTHON=$(which python3)
fi
set -e

pipx install ansible
pipx inject --include-apps ansible argcomplete

echo
echo "Success!"