#!/bin/bash
set -e

# Environment variables:
# VANTA_KEY (the Vanta per-domain secret key)
# VANTA_OWNER_EMAIL (the email of the person who owns this computer. Ignored if VANTA_KEY is missing.)

PKG_URL="https://vanta-agent.s3.amazonaws.com/v1.4.1/vanta.pkg"
# Checksum for v1.4.1; needs to be updated when PKG_URL is updated.
CHECKSUM="451aba7202128c6a69d7183811b306e410bc118c010aa1b7d7256a8552134631"
PKG_PATH="/tmp/vanta.pkg"

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
You must specify the VANTA_KEY environment variable in order to install the agent.
\n\033[0m\n"
    exit 1
fi

function onerror() {
    printf "\033[31m$ERROR_MESSAGE
Something went wrong while installing the Vanta agent.

If you're having trouble installing, please send an email to support@vanta.com, and we'll help you fix it!
\n\033[0m\n"
    $SUDO launchctl unsetenv VANTA_KEY
    $SUDO launchctl unsetenv VANTA_OWNER_EMAIL
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
downloaded_checksum=$(shasum -a256 $PKG_PATH | cut -d" " -f1)
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
$SUDO launchctl setenv VANTA_KEY "$VANTA_KEY"
$SUDO launchctl setenv VANTA_OWNER_EMAIL "$VANTA_OWNER_EMAIL"
$SUDO /usr/sbin/installer -pkg $PKG_PATH -target / >/dev/null
$SUDO launchctl unsetenv VANTA_KEY
$SUDO launchctl unsetenv VANTA_OWNER_EMAIL
rm -f $PKG_PATH

##
# check if the agent is running
# return val 0 means running,
# return val 2 means running but needs to register
##
$SUDO vanta-cli status || [ $? == 2 ]

printf "\033[32m
Your Agent is running properly. It will continue to run in the
background and submit data to Vanta.

You can check the agent status using the \"vanta-cli status\" command.

If you ever want to stop the agent, please use the toolbar icon or
the vanta-cli command. It will restart automatically at login.

To register this device to a new user, run \"vanta-cli register\" or click on \"Register Vanta Agent\"
on the toolbar.
\033[0m"
