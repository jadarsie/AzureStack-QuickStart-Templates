Add-AzureRMEnvironment -Name "AzureStackUser" -ArmEndpoint "https://management.local.azurestack.external"
# Set your tenant name
$AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackUser").ActiveDirectoryAuthority.TrimEnd('/')
$AADTenantName = "azurestackci12.onmicrosoft.com"
$TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

# After signing in to your environment, Azure Stack cmdlets
# can be easily targeted at your Azure Stack instance.
Add-AzureRmAccount -EnvironmentName "AzureStackUser" -TenantId $TenantId


$PASSWORD="javier"
$CN="registry.local.cloudapp.azurestack.external"

# Create a self-signed certificate
$ssc = New-SelfSignedCertificate -certstorelocation cert:\LocalMachine\My -dnsname $CN
$crt = "cert:\localMachine\my\" + $ssc.Thumbprint
$pwd = ConvertTo-SecureString -String $PASSWORD -Force -AsPlainText
Export-PfxCertificate -cert $crt -FilePath "onenode.pfx" -Password $pwd