packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
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

variable "ssh_public_key" {
  type    = string
  default = "" # injected via -var-file or -var at build time
}

variable "accelerator" {
  type    = string
  default = "whpx" # Windows Hypervisor Platform; falls back to "tcg" if unavailable
}

variable "ovmf_code" {
  type    = string
  default = "C:/Program Files/qemu/share/edk2-x86_64-code.fd"
}

variable "ovmf_vars" {
  type    = string
  default = "C:/Program Files/qemu/share/edk2-i386-vars.fd"
}

source "qemu" "arch" {
  vm_name          = "${var.vm_name}.qcow2"
  iso_url          = var.iso_path
  iso_checksum     = "none"
  output_directory = "output-arch"
  headless         = true

  accelerator  = var.accelerator
  machine_type = "q35"
  cpus         = 2
  memory       = 4096
  disk_size    = "20480M"
  disk_interface = "virtio-scsi" # keeps the guest's disk at /dev/sda, same as the old build

  efi_boot        = true
  efi_firmware_code = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars

  # virtio-gpu is the well-supported path for wlroots/Hyprland in a VM,
  # unlike VirtualBox's vmwgfx (see docs/testing.md for why we moved here).
  qemuargs = [
    ["-vga", "none"],
    ["-device", "virtio-gpu-pci"],
    ["-device", "virtio-keyboard-pci"],
    ["-device", "virtio-mouse-pci"]
  ]

  ssh_username         = "root"
  ssh_private_key_file = "./keys/packer_build_key"
  ssh_timeout          = "40m"

  boot_wait        = "75s"
  boot_key_interval = "80ms" # VNC key injection drops/garbles chars at the default pace
  boot_command = [
    "<enter><wait5>",
    "<enter><wait5>",
    "mkdir -p /root/.ssh<enter><wait5>",
    "echo '${var.ssh_public_key}' >> /root/.ssh/authorized_keys<enter><wait5>",
    "chmod 700 /root/.ssh<enter><wait3>",
    "chmod 600 /root/.ssh/authorized_keys<enter><wait3>",
    "systemctl start sshd<enter><wait10>"
  ]

  shutdown_command = "shutdown -h now"
}

build {
  sources = ["source.qemu.arch"]

  provisioner "shell" {
    script            = "./scripts/01-base-install.sh"
    expect_disconnect = true
  }

  provisioner "shell" {
    inline = ["mkdir -p /tmp/command-os"]
  }

  provisioner "file" {
    source      = "../../os"
    destination = "/tmp/command-os/os"
  }

  provisioner "shell" {
    script = "./scripts/02-provision-os.sh"
  }
}
