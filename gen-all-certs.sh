#!/bin/bash
#
./gen-certs.sh ca
./gen-certs.sh cert homeassistant.homelab.int
./gen-certs.sh cert unifi.homelab.int
./gen-certs.sh cert grafana.homelab.int
./gen-certs.sh cert prometheus.homelab.int
