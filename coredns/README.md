# coredns local server setup

First, download CoreDNS by running the following command:
```shell
wget https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz
tar xvf coredns_1.8.3_linux_amd64.tgz
sudo mv coredns /usr/local/bin/
rm -f coredns_1.8.3_linux_amd64.tgz
```
## configuration

```shell
sudo su -
# create hard-links to the git repo 
# change paths as appropriate
mkdir /etc/coredns && cd $_
ln /home/bashco/storage/coredns/Corefile .
ln /home/bashco/storage/coredns/db.homelab.int .
```
### setup the service file

locate at `/etc/systemd/system/coredns.service`.

```text
cat /etc/systemd/system/coredns.service
[Unit]
Description=CoreDNS DNS Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
[Install]
WantedBy=multi-user.target
```

## systemctl coredns service

sudo systemctl status coredns
sudo systemctl restart coredns

## reload has been configued on corefile 
db.homelab.int changes should reload if you change the serial number
