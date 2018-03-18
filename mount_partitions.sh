#!/bin/bash
# Mount the partitions and make swap

sudo mount -v -t ext4 /dev/sda6 $LFS
sudo mount -v -t ext4 /dev/sda3 $LFS/sources
sudo mount -v -t ext4 /dev/sda4 $LFS/home
sudo mount -v -t ext4 /dev/sda5 $LFS/opt
sudo swapon -v /dev/sda2
