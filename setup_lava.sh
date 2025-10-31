#!/bin/bash

# LAVA Server & Dispatcher Setup Script for Raspberry Pi 3
#
# This script automates the setup of a LAVA environment for testing
# Raspberry Pi Pico and STM32-446RE boards.

# --- Exit on error ---
set -e

# --- Update and upgrade the system ---
echo "Updating and upgrading the system..."
apt-get update
apt-get dist-upgrade -y

# --- Install LAVA server and dispatcher dependencies ---
echo "Installing LAVA dependencies..."
apt-get install -y ca-certificates gnupg2 wget postgresql

# --- Add LAVA repository ---
echo "Adding LAVA repository..."
wget https://apt.lavasoftware.org/lavasoftware.key.asc
apt-key add lavasoftware.key.asc
echo "deb https://apt.lavasoftware.org/release bullseye main" > /etc/apt/sources.list.d/lava.list
echo "deb http://deb.debian.org/debian bullseye-backports main" > /etc/apt/sources.list.d/backports.list
apt-get update

# --- Install LAVA server and dispatcher ---
echo "Installing LAVA server and dispatcher..."
pg_ctlcluster 13 main start
apt-get install -y lava-server
apt-get install -y -t bullseye-backports lava-dispatcher

# --- Install tools for Pico and STM32 ---
echo "Building and installing OpenOCD from source..."
apt-get install -y git autoconf libtool make pkg-config libusb-1.0-0-dev telnet
git clone https://github.com/ntfreak/openocd.git
cd openocd
./bootstrap
./configure --enable-sysfsgpio --enable-bcm2835gpio
make
make install
cd ..

echo "Installing other tools..."
apt-get install -y stlink-tools python3-pip

echo "Installing picotool..."
pip3 install picotool

echo "Setting up udev rules for Pico..."
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0003", MODE="0666"' > /etc/udev/rules.d/99-pico.rules
udevadm control --reload-rules
udevadm trigger

# --- Configure Apache ---
echo "Configuring Apache..."
a2dissite 000-default
a2enmod proxy
a2enmod proxy_http
a2ensite lava-server.conf
systemctl restart apache2

# --- Start LAVA services ---
echo "Starting LAVA services..."
systemctl start apache2
systemctl start postgresql
systemctl start lava-server-gunicorn
systemctl start lava-publisher
systemctl start lava-scheduler
systemctl start lava-worker

echo "LAVA setup script finished."
echo "Please refer to the README.md for instructions on how to configure the device-types and dispatcher."
