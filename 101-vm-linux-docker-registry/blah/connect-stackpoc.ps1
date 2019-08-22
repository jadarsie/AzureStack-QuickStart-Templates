Add-AzureRMEnvironment -Name "AzureStackPoc" -ArmEndpoint "https://management.westus2.stackpoc.com"
# Set your tenant name
$AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackPoc").ActiveDirectoryAuthority.TrimEnd('/')
$AADTenantName = "mashybridpartner.onmicrosoft.com"
$TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

# After signing in to your environment, Azure Stack cmdlets
# can be easily targeted at your Azure Stack instance.
Add-AzureRmAccount -EnvironmentName "AzureStackPoc" -TenantId $TenantId


$PASSWORD="javier"
$CN="registry.westus2.cloudapp.stackpoc.com"

# Create a self-signed certificate
$ssc = New-SelfSignedCertificate -certstorelocation cert:\LocalMachine\My -dnsname $CN
$crt = "cert:\localMachine\my\" + $ssc.Thumbprint
$pwd = ConvertTo-SecureString -String $PASSWORD -Force -AsPlainText
Export-PfxCertificate -cert $crt -FilePath "stackpoc.pfx" -Password $pwd