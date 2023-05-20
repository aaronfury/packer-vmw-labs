# Download Packer plugins
& packer.exe init ".\images\win-2022-base\main.pkr.hcl"


# Packer build
& packer.exe build -force -var-file=".\images\win-2022-base\base.auto.pkrvars.hcl" -var-file=".\secret_vars.json" ".\images\win-2022-base\main.pkr.hcl"