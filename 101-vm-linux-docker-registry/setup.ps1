# Set variables to match your environment
#########################################

$location = "westus2"
$resourceGroup = "registry-rg"

$saName = "registry"
$saContainer = "images"
$saTokenIni = Get-Date
$saTokenEnd = $saTokenIni.AddYears(1.0)

$kvName = "registry-kv"
$pfxSecret = "registry-cert"
$pfxPath = "stackpoc.pfx"
$pfxPass = "javier"
$spnName = "29320a73-239e-4d77-bd79-b47f2ff5417a"
$spnSecret = "c6_*hIaYzjgUuqpL-9w15+4@Dz[zpyF3"

$dnsLabelName = "registry"
$sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDIcNGGyQpj48OUhyQ1+n4TcT5NeZsmQq+QeFc3zBhnDbDVLwyFkR97B32PM7ENj3Feuv4xRxvGkU/gVNGMBzqF6zDNJcERjA5GfESHXIitxEAZJTLvCAW1nPIQgrz5vjZf/q3perm/lM9WgmVGyvLHe27wbyli7DLXP30Zh90JqFj68BlmMZkMjZSQrcNfkL9eba6Vf/wt6w3razP5kaOacOkmGQwulW11vtfo0KLVMduLNY700+j9tk5vWr0lK1k6izHggxn3aNvAAkSqGybMZPANpWCqubxaRnXpMC9USDaWtok0slA/EGKYAMHX5w1XmWBeTkMf4Ru6TCVqBaiXB4ond7azKbxWhdauADcmfj+55H7SxYCixafRIECMt0aV7FLPyPS1sF2vM79TkiF4eOJFeuoEE5PxnHoMJXKEGD5sUPQ9DhVFCUXO8qhjMwCyU0lZJdNIsarmOdWiLgRPxB9xOOWLOaUwcOoBg/KKQe/4S0pzqzoK3kWACY91aufs8FDyK9Habctj+yOCe9+53jNqwBxdMlETd8UUlzGUZxVIoCjDRuWMPvre+QnI9sUHFV6gJK7tN8Tnn4rLIkOPTN0au0rWg0OECU298vgHZ+j6Ut3/CJKGKTpGS5YmCPRTAVugaIvvgHQpPWNZJJoDqiFFJ6/rWRWdUfdEjasglw== jadarsie@microsoft.com"


# RESOURCE GROUP
# =============================================

# Create resource group
Write-Host "Creating resource group:" $resourceGroup
New-AzureRmResourceGroup -Name $resourceGroup -Location $location | out-null


# STORAGE ACCOUNT
# =============================================

# Create storage account
Write-Host "Creating storage account:" $saName
$sa = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName -Location $location -SkuName Premium_LRS -EnableHttpsTrafficOnly 1

# Create container
Write-Host "Creating blob container:" $saContainer
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName | out-null
$container = New-AzureStorageContainer -Name $saContainer

# Upload configuration script
Write-Host "Uploading configuration script"
Set-AzureStorageBlobContent -Container $saContainer -File script.sh | out-null
$cseToken = New-AzureStorageBlobSASToken -Container $saContainer -Blob "script.sh" -Permission r -StartTime $saTokenIni -ExpiryTime $saTokenEnd
$cseUrl = $container.CloudBlobContainer.Uri.AbsoluteUri + "/script.sh" + $cseToken


# KEY VAULT
# =============================================

# Create key vault enabled for deployment
Write-Host "Creating key vault:" $kvName
$kv = New-AzureRmKeyVault -ResourceGroupName $resourceGroup -VaultName $kvName -Location $location -Sku standard -EnabledForDeployment

Write-Host "Setting access polices"
Set-AzureRmKeyVaultAccessPolicy -VaultName $kvName -ServicePrincipalName $spnName -PermissionsToSecrets GET,LIST

# Write-Host "Storing secret for sample user: admin"
#$userSecret = ConvertTo-SecureString -String "admin" -AsPlainText -Force
#$user = Set-AzureKeyVaultSecret -VaultName $kvName -Name "admin" -SecretValue $userSecret

# Serialize certificate
$fileContentBytes = get-content $pfxPath -Encoding Byte
$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)
$jsonObject = @"
{
"data": "$filecontentencoded",
"dataType" :"pfx",
"password": "$pfxPass"
}
"@
$jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
$jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)
$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force

# Store certificate as secret
Write-Host "Storing certificate in key vault:" $pfxPath
$kvSecret = Set-AzureKeyVaultSecret -VaultName $kvName -Name $pfxSecret -SecretValue $secret -ContentType pfx

# Compute certificate thumbprint
Write-Host "Computing certificate thumbprint"
$tp = Get-PfxCertificate -FilePath $pfxPath


# BUILD TEMPLATE PARAMETERS JSON
# =============================================
$jsonParameters = New-Object -TypeName PSObject

$jsonStorageAccountResourceId = New-Object -TypeName PSObject
$jsonStorageAccountResourceId | Add-Member -MemberType NoteProperty -Name value -Value $sa.Id
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountResourceId -Value $jsonStorageAccountResourceId

$jsonStorageAccountContainerName = New-Object -TypeName PSObject
$jsonStorageAccountContainerName | Add-Member -MemberType NoteProperty -Name value -Value $saContainer
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountContainer -Value $jsonStorageAccountContainerName

$jsonKeyVaultResourceId = New-Object -TypeName PSObject
$jsonKeyVaultResourceId | Add-Member -MemberType NoteProperty -Name value -Value $kv.ResourceId
$jsonParameters | Add-Member -MemberType NoteProperty -Name keyVaultResourceId -Value $jsonKeyVaultResourceId

$jsonKeyVaultSecretUrl = New-Object -TypeName PSObject
$jsonKeyVaultSecretUrl | Add-Member -MemberType NoteProperty -Name value -Value $kvSecret.Id
$jsonParameters | Add-Member -MemberType NoteProperty -Name keyVaultSecretUrl -Value $jsonKeyVaultSecretUrl

$jsonCertificateThumbprint = New-Object -TypeName PSObject
$jsonCertificateThumbprint | Add-Member -MemberType NoteProperty -Name value -Value $tp.Thumbprint
$jsonParameters | Add-Member -MemberType NoteProperty -Name certificateThumbprint -Value $jsonCertificateThumbprint

$jsonAdminPublicKey = New-Object -TypeName PSObject
$jsonAdminPublicKey | Add-Member -MemberType NoteProperty -Name value -Value $sshKey
$jsonParameters | Add-Member -MemberType NoteProperty -Name adminPublicKey -Value $jsonAdminPublicKey

$jsonDomainNameLabel = New-Object -TypeName PSObject
$jsonDomainNameLabel | Add-Member -MemberType NoteProperty -Name value -Value $dnsLabelName 
$jsonParameters | Add-Member -MemberType NoteProperty -Name domainNameLabel -Value $jsonDomainNameLabel

$jsonCseLocation = New-Object -TypeName PSObject
$jsonCseLocation | Add-Member -MemberType NoteProperty -Name value -Value $cseUrl
$jsonParameters | Add-Member -MemberType NoteProperty -Name cseLocation -Value $jsonCseLocation

$jsonSpnName = New-Object -TypeName PSObject
$jsonSpnName | Add-Member -MemberType NoteProperty -Name value -Value $spnName
$jsonParameters | Add-Member -MemberType NoteProperty -Name servicePrincipalClientId -Value $jsonSpnName

$jsonSpnSecret = New-Object -TypeName PSObject
$jsonSpnSecret | Add-Member -MemberType NoteProperty -Name value -Value $spnSecret
$jsonParameters | Add-Member -MemberType NoteProperty -Name servicePrincipalClientSecret -Value $jsonSpnSecret

$jsonKvName = New-Object -TypeName PSObject
$jsonKvName | Add-Member -MemberType NoteProperty -Name value -Value $kvName
$jsonParameters | Add-Member -MemberType NoteProperty -Name credentialsKeyVaultName -Value $jsonKvName

$jsonRoot = New-Object -TypeName PSObject
$jsonRoot | Add-Member -MemberType NoteProperty -Name schema -Value "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
$jsonRoot | Add-Member -MemberType NoteProperty -Name contentVersion -Value "1.0.0.0"
$jsonRoot | Add-Member -MemberType NoteProperty -Name parameters -Value $jsonParameters

$jsonRoot | ConvertTo-Json | Set-Content -Path azuredeploy.parameters.json
