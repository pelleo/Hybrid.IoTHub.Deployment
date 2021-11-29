#!/bin/bash

set -euo pipefail

# Check if cloud-init is installed.
 dpkg --get-selections | grep cloud-init


# Update repository index.
apt update
apt remove --purge cloud-init -y # wipe completely
apt install cloud-init

# Verify installation.
cd /etc/cloud

# Back up original config file.
cp cloud.cfg cloud.cfg.bak

nano cloud.cfg
 # * Remove packages
 # * Disable user
 # * Exit nano

 which mkpasswd

 # If not available, install whois package.
 apt search whois

# Create password hash for user to be created.
mkpasswd -m sha-512

# Capture password hash

# Edit user section under cloud config

- name:  pelle
  lock_passwd: False
  passwd: <hash goes here>
  ssh_autorized_keys:
    - <ssh public key goes here>
  groups: [ <copy list from Azure> ]
  sudo: ["ALL=(ALL) NOPASSWD:ALL"]
  shell: /bin/bash


# Edit time zone

# Enter boot command section at the very end of file.
bootcmd:
  <enter K3s install command>

# Install packages
packages:
#  - git
#  - tmux
  - nginx

cd /etc/cloud/cloud.cfg.d

# Create new file
nano 99-fake_cloud.cfg

datasource_list [ NoCloud, None ]  # Bypass certain cloud based config options (needed for a standalone installation)
datasource:
  NoCloud:
    fs_label: system-boot

# Save file.

# Reset cloud-init to ensure no old installs are present.
cloud-init clean

# Optionally add the following lines to the cloud.cfg file:

preserve_hostname: False
hostname: <FQDN of VM>
manage_etc_hosts: true


# This is a network fix that *may* be required.
ls -al /etc/systemd/network

# Remove symlink if it exists.
rm /etc/systemd/network/99-default.link

cloud-init clean
cloud-init init

# Verify.
cat /etc/hostname
cat /etc/hostname

# To run a command:
writehomepage:              # custom block
  - &write_homepage |
    cat > /var/www/html/index.html << EOF
    <html>
      <header><title>Cloud Init</title></header>
      <body>
        <h1></h1>
      </body>
    </html>
    EOF

runcmd:
  - [ sh, -c, *write_home_homepage ]