# proxmox-ve-cloud-config
Cloud Configs for downloading and booting Proxmox VE ISOs

## How to use
1. Choose the cloud config `.yml` file that best suits you.
2. Choose `Ubuntu 22.04` as your OS.
3. Copy and paste the cloud config `.yml` contents where applicable for your cloud.  (I make use of Hetzner Cloud, though your cloud may work without any changes necessary.)
4. The Proxmox VE ISO will be downloaded over BitTorrent and booted into the graphical installer environment.
5. Once installed, the Proxmox VE web interface will be available over `HTTPS` on port `8006` by default.  Enjoy!
