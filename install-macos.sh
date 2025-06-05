#!/bin/bash
set -e

# Environment variables:
# VANTA_KEY (the Vanta per-domain secret key)
# VANTA_OWNER_EMAIL (the email of the person who owns this computer)
# VANTA_REGION (the region Vanta Device Monitor talks to, such as "us", "eu" or "aus".)

PKG_URL="https://agent-downloads.vanta.com/targets/versions/2.14.0/vanta-universal.pkg"
# Checksum needs to be updated when PKG_URL is updated.
CHECKSUM="060b408570c05f9e02eac187e3c917665c843e7a432c8d9b418ca968c5775b81"
DEVELOPER_ID="Vanta Inc (632L25QNV4)"
CERT_SHA_FINGERPRINT="D90D17FA20360BC635BC1A59B9FA5C6F9C9C2D4915711E4E0C182AA11E772BEF"
PKG_PATH="$(mktemp -d)/vanta.pkg"
VANTA_CONF_PATH="/etc/vanta.conf"

##
# Vanta needs to be installed as root; use sudo if not already uid 0
##
if [ $(echo "$UID") = "0" ]; then
    SUDO=''
else
    SUDO='sudo -E'
fi

if [ -z "$VANTA_KEY" ]; then
    printf "\033[31m
You must specify the VANTA_KEY environment variable in order to install Vanta Device Monitor.
\n\033[0m\n"
    exit 1
fi

if [ -z "$VANTA_OWNER_EMAIL" ]; then
    printf "\033[31m
You must specify the VANTA_OWNER_EMAIL environment variable in order to install Vanta Device Monitor.
\n\033[0m\n"
    exit 1
fi

if [ -z "$VANTA_REGION" ]; then
    printf "\033[31m
You must specify the VANTA_REGION environment variable in order to install Vanta Device Monitor.
\n\033[0m\n"
    exit 1
fi


function onerror() {
    printf "\033[31m$ERROR_MESSAGE
Something went wrong while installing Vanta Vanta Device Monitor.

If you're having trouble installing, please send an email to support@vanta.com, and we'll help you fix it!
\n\033[0m\n"
}
trap onerror ERR

##
# Download Vanta Device Monitor
##
printf "\033[34m\n* Downloading Vanta Device Monitor\n\033[0m"
rm -f $PKG_PATH
curl --progress-bar $PKG_URL >$PKG_PATH

##
# Checksum
##
printf "\033[34m\n* Ensuring checksums match\n\033[0m"
downloaded_checksum=$(shasum -a256 $PKG_PATH | cut -d" " -f1)
if [ $downloaded_checksum = $CHECKSUM ]; then
    printf "\033[34mChecksums match.\n\033[0m"
else
    printf "\033[31m Checksums do not match. Please contact support@vanta.com \033[0m\n"
    rm -f $PKG_PATH
    exit 1
fi

##
# Check Developer ID
##
printf "\033[34m\n* Ensuring package Developer ID matches\n\033[0m"

if pkgutil --check-signature $PKG_PATH | /usr/bin/grep -q "$DEVELOPER_ID"; then
    printf "\033[34mDeveloper ID matches.\n\033[0m"
else
    printf "\033[31m Developer ID does not match. Please contact support@vanta.com \033[0m\n"
    rm -f $PKG_PATH
    exit 1
fi

##
# Check Developer Certificate Fingerprint
##
printf "\033[34m\n* Ensuring package Developer Certificate Fingerprint matches\n\033[0m"
if pkgutil --check-signature $PKG_PATH | /usr/bin/tr -d '\n' | /usr/bin/tr -d ' ' | /usr/bin/grep -q "SHA256Fingerprint:$CERT_SHA_FINGERPRINT"; then
    printf "\033[34mDeveloper Certificate Fingerprint matches.\n\033[0m"
else
    printf "\033[31m Developer Certificate Fingerprint does not match. Please contact support@vanta.com \033[0m\n"
    rm -f $PKG_PATH
    exit 1
fi

##
# Install Vanta Device Monitor
##
printf "\033[34m\n* Installing Vanta Device Monitor. You might be asked for your password...\n\033[0m"
ACTIVATION_REQUESTED_NONCE=$(date +%s000)
CONFIG="{\"ACTIVATION_REQUESTED_NONCE\":$ACTIVATION_REQUESTED_NONCE,\"AGENT_KEY\":\"$VANTA_KEY\",\"OWNER_EMAIL\":\"$VANTA_OWNER_EMAIL\",\"NEEDS_OWNER\":true,\"REGION\":\"$VANTA_REGION\"}"
echo "$CONFIG" | $SUDO tee "$VANTA_CONF_PATH" > /dev/null
$SUDO /bin/chmod 600 "$VANTA_CONF_PATH"
$SUDO /usr/sbin/chown root:wheel "$VANTA_CONF_PATH"
$SUDO /usr/sbin/installer -pkg $PKG_PATH -target / >/dev/null
rm -f $PKG_PATH

##
# check if Vanta Device Monitor is running
# return val 0 means running,
# return val 2 means running but needs to register
##
$SUDO /usr/local/vanta/vanta-cli status || [ $? == 2 ]

printf "\033[32m
Your Vanta Device Monitor is running properly. It will continue to run in the
background and submit data to Vanta.

You can check the status of Vanta Device Monitor using the \"vanta-cli status\" command.

If you ever want to stop Vanta Device Monitor, please use the toolbar icon or
the vanta-cli command. It will restart automatically at login.

To register this device to a new user, run \"vanta-cli register\" or click on \"Register Vanta Device Monitor\"
on the toolbar.
\033[0m"
