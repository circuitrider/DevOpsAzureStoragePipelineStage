#Requires -Version 3.0

Param(
    [Parameter(Mandatory = $true)][string] $SubscriptionId,
    [Parameter(Mandatory = $true)][string] $ResourceGroupName,
    [Parameter(Mandatory = $true)][string] $ResourceGroupLocation,
    [Parameter(Mandatory = $true)][string] $StorageAccountName,
    [Parameter(Mandatory = $false)][string] $StorageContainerName = 'artifacts',
    [Parameter(Mandatory = $false)][string] $artifactsFolderName = 'artifacts',
    [switch] $GenerateSAS
)


Write-Host "##vso[task.setvariable variable=sauce]crushed tomatoes"


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


# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force
$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $artifactsFolderName))
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

Write-Host "##vso[task.setvariable variable=storageKey;issecret=true]$storageKey"

$ArtifactFilePaths = Get-ChildItem $artifactsRoot
foreach ($SourcePath in $ArtifactFilePaths) {
   
    if ([System.IO.FileAttributes]::Directory -eq $SourcePath.Attributes) {
        
        $nonRunbookFiles = Get-ChildItem $SourcePath.FullName -Recurse -File
        $rbTempArrayList = new-object system.collections.arraylist
        foreach ($f in $nonRunbookFiles) {
            
            Set-AzureStorageBlobContent -File $f.FullName -Blob $f.FullName.Substring($SourcePath.FullName.length + 1) `
                -Container $StorageContainerName -Context $storageAccount.Context -Force
                
            if ($GenerateSAS) {
                $sasToken = New-AzureStorageAccountSASToken -Service Blob -ResourceType Object -Permission "r" -ExpiryTime ((Get-Date).AddMinutes(20)) -Context $storageAccount.Context
                $absuriTemp = -join ( (Get-AzureStorageBlob -blob $Blob -Container $StorageContainerName -Context $storageAccount.Context).ICloudBlob.uri.AbsoluteUri, $sasToken)
        
                         
                $rbTemp = @{
                    runbookName = $runbook.BaseName.ToString();
                    runbookUri  = $absuriTemp.ToString();	
                };
                $rbTempArrayList.Add($rbTemp)
            }
        }
        
        Write-Output $SourcePath.FullName			
    }
    else {			
        Set-AzureStorageBlobContent -File $SourcePath.FullName -Blob $SourcePath.FullName.Substring($artifactsRoot.length + 1) `
            -Container $StorageContainerName -Context $storageAccount.Context -Force
    }
}
        
$Global:TokenSets = $null