#!/bin/bash

curl -k  -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt
update-ca-trust
rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm

subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}
dnf install samba-common-tools realmd oddjob oddjob-mkhomedir sssd adcli krb5-workstation httpd -y
setenforce 0


sudo dnf update
sudo dnf install haproxy nano -y
setenforce 0

# cat <<EOF | tee /root/.ssh/id_rsa
# -----BEGIN OPENSSH PRIVATE KEY-----
# b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
# QyNTUxOQAAACDpaoQQ8ohH8piwUjBBOQsdprVIh1aXh2aTv13u9T7r9gAAAKBpUGJJaVBi
# SQAAAAtzc2gtZWQyNTUxOQAAACDpaoQQ8ohH8piwUjBBOQsdprVIh1aXh2aTv13u9T7r9g
# AAAECXyW/JcGAAFzHipsweKvEIFVXAURrot9V7U2pbk9zqIOlqhBDyiEfymLBSMEE5Cx2m
# tUiHVpeHZpO/Xe71Puv2AAAAGnNlYW4uZS5jYXZhbmF1Z2hAZ21haWwuY29tAQID
# -----END OPENSSH PRIVATE KEY-----
# EOF

mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bk

cat <<EOF | tee /etc/haproxy/haproxy.cfg
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon
    
    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

    # utilize system-wide crypto-policies
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

frontend main
    bind *:8080
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    default_backend             app

backend static
    balance     roundrobin
## STATIC CONFIG ANSIBLE





backend app
    balance     roundrobin
## APP CONFIG ANSIBLE


EOF

systemctl enable haproxy
systemctl start haproxy

