// VM
vm_name					= 	"lab-001" 
// Operatig System (VMware Workstation 17)
// NOTE: Platform-specific; may be different with different versions of Workstation/Fusion. Edit a test VM and check the VMX file for your platform
// windows2019srvnext-64 - Windows Server 2022
// windows2019-64 - Windows Server 2019
operating_system_vm 	= 	"windows2019srvnext-64"
vm_firmware				=	"efi"
vm_cpus					= 	"2"
vm_cores				= 	"1"
vm_memory				= 	"4096"
vm_disk_controller_type = 	"nvme"
vm_disk_size			= 	"61440"
vm_network_adapter_type =   "e1000e"
// Use the NAT Network
vm_network              =   "VMnet8"
// Hardware Versions:
// 16 - Workstation 15, Fusion 11
// 18 - Workstation 16, Fusion 12
// 19 - Workstation 16.2, Fusion 12.2
// 20 - Workstation 17, Fusion 13
vm_hardwareversion 		= 	"20"

// Removable media
iso_url				= 	"D:/Virtual Machines/OS Images/Windows Server 2022 with Jan 2023 Update.iso"
// Use Get-FileHash to calculate the checksum
iso_checksum = "sha256:8E64D0CD0C69BA1DF535A04960E13BBA09E26DAA8BC0F30A570BFF741D494F9C"