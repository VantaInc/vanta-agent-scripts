#!/bin/bash

# Available environment variables:
# VANTA_KEY (the Vanta per-domain secret key)
# VANTA_NOSTART (if true, then don't start the service upon installation.)

set -e

DEB_URL="https://vanta-agent.s3.amazonaws.com/v1.4.0/vanta.deb"
RPM_URL="https://vanta-agent.s3.amazonaws.com/v1.4.0/vanta.rpm"
# Checksums for v1.4.0; need to be updated when PKG_URL is updated.
DEB_CHECKSUM="abb6fbadebbf8179e349d0a54257829b386dabe0b76e6b195ddd3b05f552cd74"
RPM_CHECKSUM="10cea2622bf286c224a71b63b9b626ec387a80f4f7699f15e7da86bce0879415"
DEB_PATH="/tmp/vanta.deb"
RPM_PATH="/tmp/vanta.rpm"
DEB_INSTALL_CMD="dpkg -Ei"
RPM_INSTALL_CMD="rpm -i"

# OS/Distro Detection
# Try lsb_release, fallback with /etc/issue then uname command
# Detection code taken from https://github.com/DataDog/datadog-agent/blob/master/cmd/agent/install_script.sh
KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|openSUSE|Amazon|Arista|SUSE)"
DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -Eo $KNOWN_DISTRIBUTION /etc/Eos-release 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

if [ -f /etc/debian_version -o "$DISTRIBUTION" == "Debian" -o "$DISTRIBUTION" == "Ubuntu" ]; then
    OS="Debian"
elif [ -f /etc/redhat-release -o "$DISTRIBUTION" == "RedHat" -o "$DISTRIBUTION" == "CentOS" -o "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
# Some newer distros like Amazon may not have a redhat-release file
elif [ -f /etc/system-release -o "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
# Arista is based off of Fedora14/18 but do not have /etc/redhat-release
elif [ -f /etc/Eos-release -o "$DISTRIBUTION" == "Arista" ]; then
    OS="RedHat"
# openSUSE and SUSE use /etc/SuSE-release or /etc/os-release
elif [ -f /etc/SuSE-release -o "$DISTRIBUTION" == "SUSE" -o "$DISTRIBUTION" == "openSUSE" ]; then
    OS="SUSE"
fi

##
# Vanta needs to be installed as root; use sudo if not already uid 0
##
if [ $(echo "$UID") = "0" ]; then
    SUDO=''
else
    SUDO='sudo -E'
fi

if [ $OS == "Debian" ]; then
    printf "\033[34m\n* Debian detected \n\033[0m"
    PKG_URL=$DEB_URL
    PKG_PATH=$DEB_PATH
    INSTALL_CMD=$DEB_INSTALL_CMD
    CHECKSUM=$DEB_CHECKSUM
elif [ $OS == "RedHat" ]; then
    printf "\033[34m\n* RedHat detected \n\033[0m"
    PKG_URL=$RPM_URL
    PKG_PATH=$RPM_PATH
    INSTALL_CMD=$RPM_INSTALL_CMD
    CHECKSUM=$RPM_CHECKSUM
    printf "Installing binutils..."
    $SUDO yum -y install binutils
else
    printf "\033[31m
Cannot install the Vanta agent on unsupported platform $DISTRIBUTION.
Please reach out to support@vanta.com for help.
\n\033[0m\n"
fi

if [ -z "$VANTA_KEY" ]; then
    printf "\033[31m
You must specify the VANTA_KEY environment variable in order to install the agent.
\n\033[0m\n"
    exit 1
fi

function onerror() {
    printf "\033[31m$ERROR_MESSAGE
Something went wrong while installing the Vanta agent.

If you're having trouble installing, please send an email to support@vanta.com, and we'll help you fix it!
\n\033[0m\n"
}
trap onerror ERR

##
# Download the agent
##
printf "\033[34m\n* Downloading the Vanta Agent\n\033[0m"
rm -f $PKG_PATH
curl --progress-bar $PKG_URL > $PKG_PATH

##
# Checksum
##
printf "\033[34m\n* Ensuring checksums match\n\033[0m"

if [ -x "$(command -v shasum)" ]; then
  downloaded_checksum=$(shasum -a256 $PKG_PATH | cut -d" " -f1)
elif [ -x "$(command -v sha256sum)" ]; then
  downloaded_checksum=$(sha256sum $PKG_PATH | cut -d" " -f1)
else
  printf "\033[31m shasum is not installed. Not checking binary contents. \033[0m\n"
  # For now, don't fail if shasum is not installed. Delete this check if you want to
  # ensure that the checksum is always enforced.
  CHECKSUM=""
fi

if [ $downloaded_checksum = $CHECKSUM ]; then
    printf "\033[34mChecksums match.\n\033[0m"
else
    printf "\033[31m Checksums do not match. Please contact support@vanta.com \033[0m\n"
    exit 1
fi

##
# Install the agent
##
printf "\033[34m\n* Installing the Vanta Agent. You might be asked for your password...\n\033[0m"
$SUDO $INSTALL_CMD $PKG_PATH

printf "\033[32m
The Vanta agent has been installed successfully.
It will continue to run in the background and submit data to Vanta.

You can check the agent status using the \"vanta-cli status\" command.
\033[0m"
