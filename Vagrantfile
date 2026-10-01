# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Segundo Parcial - Servicios Telematicos (UAO, 2026-02)
#
#   cliente-1005968285  eth1 192.168.56.20  (red "publica", host-only)
#          |
#   srv1-1005968285     eth1 192.168.56.10  (<ip publica>, UFW + DNAT)
#                       eth2 192.168.50.3   (red interna)
#          |
#   srv2-1005968285     eth1 192.168.50.2   (red interna aislada: vsftpd FTPS + SFTP)
#
# La red interna es una "intnet" de VirtualBox: ni el cliente ni el host Windows
# tienen ruta hacia 192.168.50.0/24, solo el Servidor 1.

CODIGO = "1005968285"

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.boot_timeout = 600

  # VirtualBox corre sobre Hyper-V (WSL2/Docker activos): con mas de 1 CPU
  # el arranque se cuelga, y sondear 30 puertos SATA tarda minutos.
  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 1
    vb.memory = 1024
    vb.customize ["modifyvm", :id, "--paravirt-provider", "kvm"]
    vb.customize ["storagectl", :id, "--name", "SATA Controller", "--portcount", "1"]
  end

  config.vm.define "srv1" do |srv1|
    srv1.vm.hostname = "srv1-#{CODIGO}"
    srv1.vm.network "private_network", ip: "192.168.56.10"
    srv1.vm.network "private_network", ip: "192.168.50.3", virtualbox__intnet: "intnet-parcial2"
    srv1.vm.network "forwarded_port", id: "ssh", guest: 22, host: 2601, host_ip: "127.0.0.1"
    srv1.vm.provider("virtualbox") { |vb| vb.name = "parcial2-srv1" }
    srv1.vm.provision "shell", path: "scripts/00_base.sh", args: ["srv1"]
  end

  config.vm.define "srv2" do |srv2|
    srv2.vm.hostname = "srv2-#{CODIGO}"
    srv2.vm.network "private_network", ip: "192.168.50.2", virtualbox__intnet: "intnet-parcial2"
    srv2.vm.network "forwarded_port", id: "ssh", guest: 22, host: 2602, host_ip: "127.0.0.1"
    srv2.vm.provider("virtualbox") { |vb| vb.name = "parcial2-srv2" }
    srv2.vm.provision "shell", path: "scripts/00_base.sh", args: ["srv2"]
  end

  config.vm.define "cliente" do |cliente|
    cliente.vm.hostname = "cliente-#{CODIGO}"
    cliente.vm.network "private_network", ip: "192.168.56.20"
    cliente.vm.network "forwarded_port", id: "ssh", guest: 22, host: 2603, host_ip: "127.0.0.1"
    cliente.vm.provider("virtualbox") { |vb| vb.name = "parcial2-cliente" }
    cliente.vm.provision "shell", path: "scripts/00_base.sh", args: ["cliente"]
  end
end
