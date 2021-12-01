#/bin/bash
set -euo pipefail

az login
location=westeurope                  # pipeline parameter
resourceGroupName=rg-onprem-demo     # pipeline parameter
linuxAdminUsername=adminuser         # main.bicep
vmName=demo-vm                       # main.bicep
vmSize=standard_d4s_v3               # main.bicep
publisher=Canonical                  # vm-infra.bicep
offer=UbuntuServer                   # vm-infra.bicep
sku=18.04-LTS                        # vm-infra.bicep
version=latest                       # vm-infra.bicep
networkInterfaceName=${vmName}-nic   # vm-infra.bicep

# main.bicep
sshRSAPublicKey='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsjYzxGD3DuHdin5WShA4/GMF53+0QVjCsV9dJgXrt2INF5T8LX+Gu7tFXHcKOhqkoRzqNC+jYGdEkUFqNmKtZZ0S/DflUVt+DvM7jukY/++f57UZdw1mWDtxxCK5CYg5tOzAJQC7h9YhUxaXUOTJ/uFQvm5628sIR3Id27qarV07oi56gJyD6/6AVBQWsthB8Qwif6KQdHHzH0ZW1AF5W1HVg0OGgFBsiFLQx6uQGCCQGSiyjPsM6s0UqlTvbiXbrZ0LHj+DGQp6leeZghblOw4O5jYWfIBgO1+ioVToc0U8TRuQCqerueLDH9NZxObRBpA53NTUfKf3auOgOob7l pelleo@PELLEOPC'


az vm create 
  -l ${location}
  -g ${resourceGroupName}
  -name ${vmName}
  --image ${publisher}:${offer}:${sku}:${version}
  --size ${vmSize}
  --admin-username ${linuxAdminUsername}
  --authentication-type ssh
  --ssh-key-values ${sshRSAPublicKey}
  --nics ${networkInterfaceName}
  --custom-data 
