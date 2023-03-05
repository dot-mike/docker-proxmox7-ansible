FROM debian:11

ARG DEBIAN_FRONTEND=noninteractive
ARG VE_VERSION=7.3-1
ARG MANAGER_VERSION=7.3-4

ENV pip_packages "ansible cryptography"

#set mirror
RUN rm /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian bullseye main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security/ bullseye-security main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian-security/ bullseye-security main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye-backports main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free" >> /etc/apt/sources.list

#install base pkg
RUN apt-get update && apt-get upgrade && \
    apt-get install -y \
    wget systemctl nano vim curl gnupg ca-certificates build-essential wget libffi-dev libssl-dev \
    python3-pip python3-dev python3-setuptools python3-wheel python3-apt \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

# Upgrade pip to latest version.
RUN pip3 install --upgrade pip

# Install Ansible via pip.
RUN pip3 install $pip_packages

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible
RUN echo "[local]\nlocalhost ansible_connection=local" > /etc/ansible/hosts

#add proxmox repo
RUN echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" >>/etc/apt/sources.list.d/pve-install-repo.list && \
    curl https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg|apt-key add -

#repacked proxmox-ve
RUN wget http://download.proxmox.com/debian/pve/dists/bullseye/pve-no-subscription/binary-amd64/proxmox-ve_${VE_VERSION}_all.deb && \
    mkdir /tmp/pve && \
    dpkg -X proxmox-ve_${VE_VERSION}_all.deb /tmp/pve/ && \
    dpkg -e proxmox-ve_${VE_VERSION}_all.deb /tmp/pve/DEBIAN && \
    sed -i -e 's/\bpve-kernel-[^ ]*//g' /tmp/pve/DEBIAN/control && \
    dpkg-deb -Zxz  -b /tmp/pve/ /tmp/

#repacked pve-manager
RUN wget http://download.proxmox.com/debian/pve/dists/bullseye/pve-no-subscription/binary-amd64/pve-manager_${MANAGER_VERSION}_amd64.deb && \
    mkdir /tmp/pve-manager && \
    dpkg -X pve-manager_${MANAGER_VERSION}_amd64.deb  /tmp/pve-manager/ && \
    dpkg -e pve-manager_${MANAGER_VERSION}_amd64.deb /tmp/pve-manager/DEBIAN && \
    sed -i -e 's/\b, ifupdown2[^,]*//g' /tmp/pve-manager/DEBIAN/control && \
    dpkg-deb -Zxz  -b /tmp/pve-manager/ /tmp

#intall proxmox-ve without recommends. ifupdown2 will install failed but ok
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractiv apt-get -y --no-install-recommends  install  proxmox-ve rsyslog chrony ksmtuned dialog || echo ok

##install again
RUN dpkg -i /tmp/*.deb || echo ok

RUN rm -rf /etc/apt/sources.list.d/pve-enterprise.list

#set passwd for root
RUN echo "root:proxmox"|chpasswd

RUN echo "#deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" >/etc/apt/sources.list.d/pve-install-repo.list
#&& \ apt-get update && apt-get -y upgrade && \
#apt-get -y autoremove && \
#apt-get -y install ifupdown2

#clean cache / module vhost_net
RUN rm -rf /var/lib/apt/lists/*  /*.deb &&\
    rm -f /etc/modules-load.d/qemu-server.conf &&\
    rm /etc/network/interfaces.new

#enable networking
RUN systemctl enable networking

ENV TZ="Europe/Berlin"


EXPOSE 8006/tcp
VOLUME [ "/var/lib/vz" ]

#use setup.sh to start proxmox service
STOPSIGNAL SIGINT
CMD [ "/lib/systemd/systemd", "log-level=info", "unit=sysinit.target"]
