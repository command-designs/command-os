packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "iso_path" {
  type    = string
  default = "./iso/archlinux-x86_64.iso"
}

variable "vm_name" {
  type    = string
  default = "command-os-dev"
}

source "virtualbox-iso" "arch" {
  vm_name          = var.vm_name
  guest_os_type    = "ArchLinux_64"
  iso_url          = var.iso_path
  iso_checksum     = "none"
  firmware         = "efi"
  cpus             = 2
  memory           = 4096
  disk_size        = 20480
  headless         = true
  keep_registered  = true
  skip_export      = true
  shutdown_command = "shutdown -h now"
  ssh_username     = "root"
  ssh_password     = "packer"
  ssh_timeout      = "40m"
  ssh_port         = 22

  boot_wait = "25s"
  boot_command = [
    "<enter><wait10>",
    "echo root:packer | chpasswd<enter><wait2>",
    "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config<enter><wait2>",
    "systemctl start sshd<enter><wait5>"
  ]
}

build {
  sources = ["source.virtualbox-iso.arch"]

  provisioner "shell" {
    script            = "./scripts/01-base-install.sh"
    expect_disconnect = true
  }

  provisioner "file" {
    source      = "../../os"
    destination = "/tmp/command-os/os"
  }

  provisioner "shell" {
    script = "./scripts/02-provision-os.sh"
  }
}
