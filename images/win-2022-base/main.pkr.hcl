############################################
## Lab Base Image -  Windows Server 2022 ##
############################################
packer {
  required_version = ">= 1.8.0"
  required_plugins {
    vmware = {
      version = " >= 1.0.6"
      source  = "github.com/hashicorp/vmware"
    }
  }

  required_plugins {
    windows-update = {
      version = " >= 0.14.1"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "vm_name" {
  type    = string
  description = "Image name"
}

variable "operating_system_vm" {
  type    = string
  description = "OS Guest OS"
}

variable "vm_cores" {
  type    = string
  description = "Amount of cores"
}

variable "vm_cpus" {
  type    = string
  description = "amount of vCPUs"
}

variable "vm_disk_controller_type" {
  type    = string
  description = "Controller type"
}

variable "vm_disk_size" {
  type    = string
  description = "Harddisk size"
}

variable "vm_hardwareversion" {
  type    = string
  description = "VM hardware version"
}

variable "vm_firmware" {
  type        = string
  description = "The virtual machine firmware. (e.g. 'efi-secure'. 'efi', or 'bios')"
  default     = "efi-secure"
}

variable "vm_cdrom_type" {
  type        = string
  description = "The virtual machine CD-ROM type. (e.g. 'sata', or 'ide')"
  default     = "sata"
}

variable "vm_memory" {
  type    = string
  description = "VM Memory"
}

variable "vm_network_adapter_type" {
  type    = string
  description = "Networkadapter type"
}

variable "vm_network" {
  type    = string
  description = "Network"
}

variable "iso_path" {
  type    = string
  description = "Windows ISO location"
}

variable "winrm_username" {
  type    = string
  description = "winrm username"
}

variable "winrm_password" {
  type    = string
  description = "winrm password"
}

source "vmw" "lab_windows_2022_base" {
	vm_name = var.vm_name
	// Hardware specs
	cpus = var.vm_cpus
	cores = var.vm_cores
	memory = var.vm_memory
	disk_size = var.vm_disk_size
	disk_adapter_type = var.vm_disk_controller_type
	// Disk Types:
	// 0 - Growable, single file
	// 1 - Growable, 2GB files
	// 2 - Preallocated, single file
	// 3 - Preallocated, 2GB files
	disk_type_id = 0
	network_adapter_type = var.vm_network_adapter_type
	network = var.vm_network 
	cdrom_adapter_type = "ide"

	// Guest OS
	guest_os_type = var.operating_system_vm
	version = var.vm_hardwareversion
	iso_url = var.iso_path
	iso_checksum = var.iso_checksum
	floppy_files = ["${path.root}/files/floppy/"]
	floppy_label = "floppy"

	// WinRM 
	insecure_connection       = "true"
	communicator              = "winrm"
	winrm_port                = "5985"
	winrm_username            = var.winrm_username
	winrm_password            = var.winrm_password
	winrm_timeout             = "12h"
	shutdown_command          = "shutdown /s /t 10 /f"
}

build {
  sources = ["source.vmw.lab_windows_2022_base"]

  provisioner "powershell" {
    script = "./image-creation/scripts/create-folders.ps1"
  }

  provisioner "file" {
	source = "./image-creation/files/temp/"
	destination = "C:/Temp/"
  }

  provisioner "powershell" {
    script = "./image-creation/scripts/remove-features-part1.ps1"
  }

  # Restart here to finish removing Windows Defender, which will speed up the rest of the process. It's also necessary to split up removing Windows "Features" and "Capabilities". Attempting to do both without a reboot causes the removal of *EVERYTHING* to fail.
  provisioner "windows-restart" {}

  provisioner "powershell" {
    script = "./image-creation/scripts/remove-features-part2.ps1"
  }

  # This will create any accounts needed by the image.
  provisioner "powershell" {
    script           = "./image-creation/scripts/create-accounts.ps1"
    environment_vars = split(",", var.default_user_password)
  }

  # This will set the KMS server for itopia Windows images.
  provisioner "powershell" {
    script           = "./image-creation/scripts/set-kms-server.ps1"
    environment_vars = split(",", var.scripts.script_set_kms_server_env_vars)
    valid_exit_codes = [0, 3221549112]
  }

  # Set a bunch of user configuration into the "default" user profile, so that all new user profiles get these values
  provisioner "powershell" {
    script = "./image-creation/scripts/set-default-user-registry.ps1"
  }

  # Enable the built-in Photo Viewer, which is disabled by default
  provisioner "powershell" {
    script  = "./image-creation/scripts/enable-photo-viewer.ps1"
  }

  # Run Windows Update. This provisioner automatically restarts the machine when the updates are complete.
  provisioner "windows-update" {
  }

  # Install Firefox
  provisioner "powershell" {
    script = "./image-creation/scripts/install-firefox.ps1"
  }

  # This will "optimize" any .NET applications during the build phase so it will not happen during first boot when the user logs on.
  provisioner "powershell" {
    script = "./image-creation/scripts/optimize-dotNet.ps1"
  }

  # TODO: Run the Windows Disk Cleanup Utility
  # Sample script available here: https://www.powershellgallery.com/packages/Invoke-WindowsDiskCleanup/1.0/Content/Invoke-WindowsDiskCleanup.ps1
}