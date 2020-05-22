# sidhistory_cloner
Library for cloning sid history

This contains needed files to clone a sid from one domain to another, based on samAccountName.
Powershell executes, pulls the dll needed, and executes it.

Some AVs may trip on the dll, may have to disable to do it.

# How to run.
1. Download sid_history_clone.ps1
2. Run it (typically as domain admin from the target domain)

```
#Example
$sourceCredential = get-credential
$targetCredential = get-credential
sid_history_clone.ps1 `
  -sourceCredential $sourceCredential `
  -sourceSAMAccountName "jon.doe" `
  -sourceDomain "myolddomain" `
  -targetSAMAccountName "jdoe" `
  -targetDomain "mynewdomain" `
  -targetCredential $targetCredential
```
