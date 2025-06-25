#!/bin/bash

nmcli connection add type ethernet con-name enp2s0 ifname enp2s0 ipv4.addresses 192.168.1.11/24 ipv4.method manual connection.autoconnect yes
nmcli connection up enp2s0

echo "192.168.1.10 control.lab control" >> /etc/hosts

echo "192.168.1.11 node01.lab node01" >> /etc/hosts

echo "192.168.1.100 windows.lab windows" >> /etc/hosts
echo "192.168.1.101 dbserver.lab dbserver" >> /etc/hosts


curl -k  -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt
update-ca-trust
rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm

subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}
dnf install samba-common-tools realmd oddjob oddjob-mkhomedir sssd adcli krb5-workstation httpd -y
setenforce 0

cp /etc/resolv.conf /tmp/resolv.conf


cat <<EOF | tee /var/www/html/index.html


<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nothing to See Here</title>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            color: #333;
        }
        h1 {
            font-size: 3em;
            text-align: center;
        }
    </style>
</head>
<body>
    <h1>Nothing to See Here - Not Yet Anyway - Node01 </h1>
</body>
</html>

EOF

systemctl start httpd
