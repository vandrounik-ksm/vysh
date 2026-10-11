#!/bin/sh
set -e
install -d -m 700 -o demo -g demo /home/demo/.ssh
install -m 600 -o demo -g demo /authorized_keys /home/demo/.ssh/authorized_keys
exec /usr/sbin/sshd -D -e
