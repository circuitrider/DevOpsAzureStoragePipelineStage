# Azure Storage Pipeline Stage for DevOps
The purpose of this is to allow applications to load artifacts into a staging Azure Storage Account for use by ARM templates and downstream consumers such as DSC configuration extensions in a secure and maintainable way.

## Usage
Include stage.ps1 in your artifacts published for a release pipeline. Then create an Azure PowerShell task referencing this script. Pass the parameters to this via pipeline Variables or Variable Groups.

Set the **$ArtifactsPath** parameter to be the relative path to the root directory of where your files are which need to be loaded into Storage for use in later Tasks or after deployment.

All files in this path will be loaded into the designated Container, maintaining the same folder structure.

If the **$GenerateSAS** switch is set, then each individual file will have a SAS URL generated for it which can be used in later tasks.

## Session Environmental Variables

### Storage Account Key
Tasks after this one are run can access the Storage Account access key as an environmental variable in two ways.

**As a variable referenced in the Task Configuration**

    $(STORAGEKEY) 

**As a variable in a PowerShell script**

    $env:STORAGEKEY

### Per-file SAS URLs

If generated, each file's corresponding SAS URL can be found as an environmental variable in a similar manner as the Storage Account Key. 

Example, if you had a file in *artifacts/someSubFolder/someFile.txt* then it will be available in two possible ways.

    $(ARTIFACTSSOMESUBFOLDERSOMEFILETXT)

    $env:ARTIFACTSSOMESUBFOLDERSOMEFILETXT

You can dynamically transform filenames from your artifacts to get this in this way.

    (Get-ChildItem "env:$pathToFile").Value
