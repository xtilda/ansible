#!/usr/bin/env bash
set -e
mkdir -p /var/run/sshd
/usr/sbin/sshd
exec /bin/bash
