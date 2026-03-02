#!/bin/bash

# Exit immediately if a command fails
set -e

DISK="/dev/sdc"

echo "Creating partitions on $DISK..."

# Create partition table and partitions
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary 1MiB 3GiB
parted -s $DISK mkpart primary 3GiB 100%

# Inform kernel of partition changes
partprobe $DISK
sleep 2

# Create Physical Volumes
pvcreate ${DISK}1
pvcreate ${DISK}2

# Create Volume Groups
vgcreate teachersVG ${DISK}1
vgcreate studentsVG ${DISK}2

# Create Teacher Logical Volumes (600M each)
for subject in science english math PE language
do
    lvcreate -L 600M -n $subject teachersVG
done

# Create Student Logical Volumes (500M each)
for class in freshman sophmore junior senior
do
    lvcreate -L 500M -n $class studentsVG
done

# Create XFS filesystems
for lv in science english math PE language
do
    mkfs.xfs /dev/teachersVG/$lv
done

for lv in freshman sophmore junior senior
do
    mkfs.xfs /dev/studentsVG/$lv
done

# Create mount directories
mkdir -p /teachers/{science,english,math,PE,language}
mkdir -p /students/{freshman,sophmore,junior,senior}

# Mount and add UUID to fstab
for lv in science english math PE language
do
    UUID=$(blkid -s UUID -o value /dev/teachersVG/$lv)
    echo "UUID=$UUID /teachers/$lv xfs defaults 0 0" >> /etc/fstab
    mount /teachers/$lv
done

for lv in freshman sophmore junior senior
do
    UUID=$(blkid -s UUID -o value /dev/studentsVG/$lv)
    echo "UUID=$UUID /students/$lv xfs defaults 0 0" >> /etc/fstab
    mount /students/$lv
done

echo "Verifying mounts..."
mount -a

echo "Done. LVM structure created successfully."
