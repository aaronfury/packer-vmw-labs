# packer-vmw-labs
Packer scripts for configuring lab VMs in VMware Workstation

## Notes
- The Administrator password is "Password123!" (no quotes). Change this in the **files\floppy\unattend.xml** file
- The "build-lab-base.ps1" script relies on a *secret_vars.json* file to provide the sensitive parameters (like KMS host name and winrm_username/password). This file is not included in the repo for obvious reasons. Create this variables file and populate it with the necessary values.