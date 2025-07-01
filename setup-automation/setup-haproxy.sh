#!/bin/bash

curl -k  -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt
update-ca-trust
rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm

subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}
dnf install haproxy -y
setenforce 0

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
    
    # Check for root path and serve custom load balancer page
    acl is_root_path path /
    use_backend loadbalancer_page if is_root_path
    
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js
    use_backend static          if url_static
    default_backend             app

# New backend for load balancer demo page
backend loadbalancer_page
    mode http
    http-request return status 200 content-type "text/html" string "<!DOCTYPE html>\n<html>\n<head>\n    <title>Load Balancer</title>\n    <meta http-equiv=\"refresh\" content=\"3\">\n    <style>\n        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }\n        .container { background: rgba(255,255,255,0.1); padding: 40px; border-radius: 10px; display: inline-block; }\n        h1 { font-size: 2.5em; margin-bottom: 20px; }\n        p { font-size: 1.2em; }\n        .refresh-info { margin-top: 20px; font-size: 0.9em; opacity: 0.8; }\n        .port-info { margin-top: 10px; font-size: 0.8em; }\n    </style>\n</head>\n<body>\n    <div class=\"container\">\n        <h1>🔄 Load Balancer</h1>\n        <p>Refresh for next webserver</p>\n        <div class=\"refresh-info\">Auto-refresh every 3 seconds</div>\n        <div class=\"port-info\">Running on port 8080</div>\n    </div>\n</body>\n</html>"

backend static
    balance     roundrobin
    # If no static servers available, fallback to load balancer page
    http-request return status 200 content-type "text/html" string "<!DOCTYPE html>\n<html>\n<head>\n    <title>Load Balancer - Static</title>\n    <meta http-equiv=\"refresh\" content=\"3\">\n</head>\n<body style=\"text-align:center;font-family:Arial;margin-top:100px;background:#f0f0f0\">\n    <h1>🔄 Load Balancer - Static Backend</h1>\n    <p>No static servers available. Refresh for next webserver</p>\n</body>\n</html>" if !{ nbsrv(static) gt 0 }
## STATIC CONFIG ANSIBLE

backend app
    balance     roundrobin
    # If no app servers available, fallback to load balancer page
    http-request return status 200 content-type "text/html" string "<!DOCTYPE html>\n<html>\n<head>\n    <title>Load Balancer - App</title>\n    <meta http-equiv=\"refresh\" content=\"3\">\n</head>\n<body style=\"text-align:center;font-family:Arial;margin-top:100px;background:#e8f4fd\">\n    <h1>🔄 Load Balancer - App Backend</h1>\n    <p>No app servers available. Refresh for next webserver</p>\n</body>\n</html>" if !{ nbsrv(app) gt 0 }
## APP CONFIG ANSIBLE
EOF

systemctl enable haproxy
systemctl start haproxy
