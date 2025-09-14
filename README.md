# homelab

HP Elitebook requires disabling power management to stop random [reboots](https://forum.proxmox.com/threads/proxmox-random-reboots-on-hp-elitedesk-800g4-fixed-with-proxmox-install-on-top-of-debian-12-now-issues-with-hardware-transcoding-in-plex.132187/page-2). _i915.enable_dc=0_ needs to be added to the _GRUB_CMDLINE_LINUX_DEFAULT_
value in `/etc/default/grub`.

```text
GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_dc=0 intel_idle.max_cstate=7"
```

Then update grub and reboot the system

```shell
sudo update-grub
sudo shutdown -r now
```

The nginx reverse proxy diagram.

![Alt text](./mermaid.svg)

## ubuntu upgrades

```shell
sudo apt-get --with-new-pkgs upgrade # upgrades held back packages
```

## changing from docker snap to native docker

```shell
sudo snap stop docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
sudo rsync -a /var/snap/docker/common/var-lib-docker/ /var/lib/docker/
sudo snap remove docker
/usr/bin/docker compose up -d # bring up the rest of the stack
```

## certificates for a homelab

- Provision a CA. See the [gen-certs.sh](./gen-certs.sh) script.
- Use the CA to create self-signed certificates for nginx/application
- Import and trust the CA on machines in your lab. Use AirDrop to copy the CA to iPhone. Add the Profile in VPN management and then trust the CA in "Settings -> About". For macOS, use KeyChain Access to import the CA and then change the Trust Level.

## coredns for local home domain

Router updated to use the ip address of the host running the docker container of coredns via host network mode.
Added prometheus and cache plgins to the Corefile.
Change the local machine to use CoreDNS.

Install coredns

```shell
sudo mkdir /etc/coredns
sudo cp coredns/* /etc/coredns/
wget https://github.com/coredns/coredns/releases/download/v1.12.3/coredns_1.12.3_linux_amd64.tgz
mv coredns_1.12.3_linux_amd64.tgz /tmp
tar xzf -C /tmp coredns_1.12.3_linux_amd64.tgz
chmod +x /tmp/coredns
sudo mv /tmp/coredns /usr/local/bin
```

Set the content of `/etc/systemd/system/coredns.service`

```text
[Unit]
Description=CoreDNS DNS Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
[Install]
WantedBy=multi-user.target
```

Start the CoreDNS service

```shell
sudo systemctl daemon-reload
sudo systemctl start coredns
sudo systemctl status coredns
sudo systemctl enable coredns
```

### change the local resolver to use coredns

```shell
# edit  /etc/systemd/resolved.conf
# set the below value
DNSStubListener=no

# Then apply your changes by running the following command:

sudo systemctl restart systemd-resolved
```

You may need to also change the `/etc/resolv.conf` file too

- DNS [reference](https://di-marco.net/blog/it/2024-05-09-Intall_and_configure_coredns/#disable-stub-resolver)
- CoreDNS [reference](https://ipv6.rs/tutorial/Ubuntu_Server_Latest/CoreDNS/)

## prometheus

### update the config for a live reload

```shell
curl --insecure -X POST https://prometheus.homelab.int/-/reload
```

## grafana

Provisioning [reference](https://medium.com/56kcloud/provisioning-grafana-data-sources-and-dashboards-auto-magically-e27155d20652)
Reset the admin user password

```shell
docker compose exec grafana /bin/sh
grafana cli admin reset-admin-password admin
```

- coredns [dashboard](https://grafana.com/grafana/dashboards/15762-kubernetes-system-coredns/).
- node-exporter: import dashboard 1860 and set Job to `node-exporter`.

## node--exporter

Runs in host mode and therefore the prom scrape address needs to be the machine host IP address.

## atuin

Sync your terminal history between machines. Can either use the online sync service or host your own.

[Github](https://github.com/atuinsh/atuin/)
PostGreSQL [backup](https://github.com/prodrigestivill/docker-postgres-backup-local)
Atuin docker image runs as atuin with ids 1000:1000

/opt/atuin for the docker-compose.sh

The docker-compose file:

```shell
networks:
  data:
    driver: bridge
  storage_proxy:
    external: true

services:
  atuin:
    restart: unless-stopped
    image: ghcr.io/atuinsh/atuin:18.8.0
    command: server start
    depends_on:
      - atuin_db
    ports:
      - 8888:8888
    env_file:
      - .env
    environment:
      ATUIN_HOST: "0.0.0.0"
      ATUIN_OPEN_REGISTRATION: "true"
      ATUIN_DB_URI: postgres://$ATUIN_DB_USERNAME:$ATUIN_DB_PASSWORD@atuin_db/$ATUIN_DB_NAME
      RUST_LOG: info,atuin_server=debug
    networks:
      - storage_proxy
      - data

  atuin_db:
    image: postgres:14.19
    restart: unless-stopped
    env_file:
      - .env
    volumes: # Don't remove permanent storage for index database files!
      - "./pg_data:/var/lib/postgresql/data/"
    environment:
      POSTGRES_USER: ${ATUIN_DB_USERNAME}
      POSTGRES_PASSWORD: ${ATUIN_DB_PASSWORD}
      POSTGRES_DB: ${ATUIN_DB_NAME}
    networks:
      - data

  backup:
    container_name: atuin_db_dumper
    image: prodrigestivill/postgres-backup-local
    user: postgres:postgress
    env_file:
      - .env
    environment:
      POSTGRES_HOST: atuin_db
      POSTGRES_DB: ${ATUIN_DB_NAME}
      POSTGRES_USER: ${ATUIN_DB_USERNAME}
      POSTGRES_PASSWORD: ${ATUIN_DB_PASSWORD}
      SCHEDULE: "@daily"
      BACKUP_ON_START: TRUE
      BACKUP_DIR: /db_dumps
      POSTGRES_EXTRA_OPTS: -Z1 --schema=public --blobs
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 6
    volumes:
      - ./db_dumps:/db_dumps
    depends_on:
      - atuin_db
    networks:
      - data
```

The contents of the `.env` file - redacted.

```shell
ATUIN_DB_NAME=XXX
ATUIN_DB_USERNAME=XXX
# Choose your own secure password
ATUIN_DB_PASSWORD=XXX
```

```shell
sudo mkdir -p /opt/atuin/pg_data
sudo chown 999:docker /opt/atuin/db_dumps
sudo chmod 700 /opt/atuin/db_dumps
sudo mkdir -p /opt/atuin/db_dumps
sudo chown 999:999 /opt/atuin/db_dumps
```

And start it up

```shell
$ cd /opt/atuin
$ docker compose up -d

# after you registered and login and synced...
# create the first backup
$ docker compose exec -ti  backup /bin/sh
./backup.sh
exit

# verify you have some sql files...
$ ls -Rt /opt/atuin/db_dumps
/opt/atuin/db_dumps:
monthly  weekly  daily  last

/opt/atuin/db_dumps/monthly:
atuin-latest.sql.gz  atuin-202509.sql.gz

/opt/atuin/db_dumps/weekly:
atuin-latest.sql.gz  atuin-202537.sql.gz

/opt/atuin/db_dumps/daily:
atuin-latest.sql.gz  atuin-20250914.sql.gz

/opt/atuin/db_dumps/last:
atuin-latest.sql.gz  atuin-20250914-184137.sql.gz
```

## references

- Homelab [CoreDNS setup](https://medium.com/@bensoer/setup-a-private-homelab-dns-server-using-coredns-and-docker-edcfdded841a)
- Docker [compose](https://docs.docker.com/compose/)
- Provisioning [grafana and prom](https://medium.com/56kcloud/provisioning-grafana-data-sources-and-dashboards-auto-magically-e27155d20652)
- checkout the [repo](https://github.com/vegasbrianc/prometheus/tree/master) for prom setup etc
- Unifi [controller](https://github.com/jacobalberty/unifi-docker/) setup
- Not used, but looks interesting - [dockerize your dev](https://github.com/RiFi2k/dockerize-your-dev)
