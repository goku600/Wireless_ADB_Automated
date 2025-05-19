#!/bin/bash

# Exit on error
set -e

# Must be root for nmap scan
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

# Detect active interface
INTERFACE=$(ip -o -4 addr show up | grep -v ' lo ' | awk '{print $2}' | head -n 1)

if [ -z "$INTERFACE" ]; then
  echo "Could not detect active network interface."
  exit 1
fi

# Get subnet in CIDR format
SUBNET=$(ip -4 addr show "$INTERFACE" | grep -oP 'inet \K[\d.]+/\d+')

if [ -z "$SUBNET" ]; then
  echo "Could not determine subnet for interface $INTERFACE."
  exit 1
fi

echo "Using interface: $INTERFACE"
echo "Scanning subnet: $SUBNET for devices with port 5555 (ADB) open..."

# Get IPs with port 5555 open
mapfile -t ADB_DEVICES < <(nmap -p 5555 --open -T4 "$SUBNET" | grep 'Nmap scan report for' | awk '{print $NF}')

if [ ${#ADB_DEVICES[@]} -eq 0 ]; then
  echo "No devices with port 5555 open were found."
  exit 0
fi

echo -e "\nDevices with ADB port (5555) open:"
for i in "${!ADB_DEVICES[@]}"; do
  printf "%d) %s\n" "$((i+1))" "${ADB_DEVICES[$i]}"
done

# Ask user to select a device
read -p $'\nChoose a device number to connect via ADB: ' CHOICE

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#ADB_DEVICES[@]}" ]; then
  echo "Invalid selection."
  exit 1
fi

TARGET_IP="${ADB_DEVICES[$((CHOICE-1))]}"
echo -e "\nConnecting to $TARGET_IP via ADB..."

# Try connecting
adb connect "$TARGET_IP"

# Give some time for the connection to establish
sleep 1

# Launch adb shell
echo "Launching ADB shell..."
adb -s "$TARGET_IP:5555" shell

