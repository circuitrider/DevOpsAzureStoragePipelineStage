# Azure Storage Pipeline Stage for DevOps
The purpose of this is to allow applications to load artifacts into a staging Azure Storage Account for use by ARM templates and downstream consumers such as DSC configuration extensions in a secure and maintainable way.

Tasks after this one are run can access the Storage Account access key as an environmental variable in two ways.

**As a variable referenced in the Task Configuration**

    $(STORAGEKEY) 

**As a variable in a PowerShell script**

    $env:STORAGEKEY


