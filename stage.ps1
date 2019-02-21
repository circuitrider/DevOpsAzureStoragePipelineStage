#Requires -Version 3.0

Param(
    [Parameter(Mandatory = $true)][string] $SubscriptionId,
    [Parameter(Mandatory = $true)][string] $ResourceGroupName,
    [Parameter(Mandatory = $true)][string] $ResourceGroupLocation,
    [Parameter(Mandatory = $true)][string] $StorageAccountName,
    [Parameter(Mandatory = $false)][string] $StorageContainerName = 'artifacts',
    [Parameter(Mandatory = $false)][string] $ArtifactsPath = 'artifacts',
    [switch] $GenerateSAS
)

$Global:TokenSets = $null
$ErrorActionPreference = 'Stop'

write-warning "Setting AzureRMContext"
write-warning "context = Set-AzureRmContext -SubscriptionId $SubscriptionId"

$context = Set-AzureRmContext -SubscriptionId $SubscriptionId

write-warning "Context related information"
write-warning "Context Name       = $($context.Name)"
write-warning "Context Account id = $($context.Account.Id)"
write-warning "Context SubscName  = $($context.Subscription)"
write-warning "Context Environment= $($context.Environment)"
write-warning "Context Tenant id  = $($context.Tenant.Id)"



$resourceGroupOutput = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force
$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactsPath))
$storageAccount = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction Ignore
if (!$storageAccount) {
    Write-Output 'Creating new storage account, please wait...'
    $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -Location $ResourceGroupLocation `
        -SkuName Standard_LRS `
        -Kind Storage
}
$ctx = $storageAccount.Context
$storageContainer = Get-AzureStorageContainer -Name $StorageContainerName -Context $ctx -ErrorAction Ignore
if (!$storageContainer) {
    $storageContainer = New-AzureStorageContainer -Name $StorageContainerName -Context $ctx -Permission blob
}
$storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value.ToString()

Write-Host "##vso[task.setvariable variable=STORAGEKEY;issecret=true]$storageKey"
function traverse($rootPath) {
    $children = Get-ChildItem $rootPath
    foreach ($child in $children) {        
        if ([System.IO.FileAttributes]::Directory -eq $child.Attributes) {
            traverse $child.FullName
        }
        else {
            $sasOutput = uploadFile -filePath $child.Fullname -blobName $child.FullName.Replace($artifactsRoot + '\', '').Replace('\', '/') `
                -containerName $StorageContainerName -storageAccountContext $storageAccount.Context
            
            if ($GenerateSAS) {
                $envVarName = $child.FullName.Replace($PSScriptRoot, '').Replace('\', '').Replace('.', '').ToUpper();
                Write-Host "##vso[task.setvariable variable=$envVarName;issecret=true]$sasOutput"
            }
        }
    }
}
function uploadFile($filePath, $blobName, $containerName, $storageAccountContext) {
    $blobOutput = Set-AzureStorageBlobContent -File $filePath -Blob $blobName `
        -Container $containerName -Context $storageAccountContext -Force
            
    if ($GenerateSAS) {
        $sasToken = New-AzureStorageAccountSASToken -Service Blob -ResourceType Object -Permission "r" -ExpiryTime ((Get-Date).AddMinutes(20)) -Context $storageAccountContext
        $b = Get-AzureStorageBlob -blob $blobName -Container $containerName -Context $storageAccountContext
        $absuriTemp = -join ($b.ICloudBlob.uri.AbsoluteUri, $sasToken)
        return $absuriTemp;
    }
    return $null
}
traverse $artifactsRoot
# foreach ($SourcePath in $ArtifactFilePaths) {
#     Write-Output $SourcePath
#     $nonRunbookFiles = Get-ChildItem $SourcePath.FullName -Recurse -File
    
#     foreach ($f in $nonRunbookFiles) {

#     }
        
    
# }
        
$Global:TokenSets = $null