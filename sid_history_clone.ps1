param(
    [parameter(Mandatory = $true)]$sourceCredential = (get-credential),
    [parameter(Mandatory = $true)]$sourceSAMAccountName,
    [parameter(Mandatory = $true)]$sourceDomain,
    [parameter(Mandatory = $true)]$targetSAMAccountName,
    [parameter(Mandatory = $true)]$targetDomain,
    $targetCredential = $sourceCredential
)
try
{
    Write-Verbose "Dynamically determining PDC DC for source domain"
        $sourceDC = (Get-ADDomain -Server $sourceDomain).pdcemulator
        if(-not $sourceDC)
        {
            throw "Source PDC DC could not be determined from $sourceDomain"
        }

    Write-Verbose "Dynamically determining PDC DC for target domain"
        $targetDC = (Get-ADDomain -Server $targetDomain).pdcemulator
        if(-not $targetDC)
        {
            throw "Target PDC DC could not be determined from $targetDomain"
        }

    Write-Verbose "Verifying samaccountname exists on source"
        $sourceADObject = get-adobject -filter {samaccountname -eq $sourceSAMAccountName} -server $sourceDC -Properties ObjectSID, SidHistory
        if(-not $sourceADObject)
        {
            throw "[$sourceSAMAccountName] does not exist on [$sourceDC]"
        }

    Write-Verbose "Checking if sid already exists in another accounts sid history"
        $existingSID = $($sourceADObject.objectsid.value)
        $sidExistsUser = get-adobject -server $targetDC -Filter {SidHistory -like $existingSID} -Properties ObjectSID, SidHistory, samaccountname
        if($sidExistsUser -and $sidExistsUser.samaccountname -eq $targetSAMAccountName)
        {
            write-host "[SKIP] SID History for [$($sourceDomain)\$sourceSAMAccountName] -> [$($targetDomain)\$targetSAMAccountName] already migrated"
            return
        }elseif($sidExistsUser -and $sidExistsUser.samaccountname -ne $targetSAMAccountName)
        {
            write-warning "[SKIP] SID History for [$($sourceDomain)\$sourceSAMAccountName] -> [$($targetDomain)\$targetSAMAccountName] already exists for another account [$($sidExistsUser.samaccountname)]"
            return
        }

    Write-Verbose "Verifying samaccountname exists on target"
        $targetADObject = get-adobject -filter {samaccountname -eq $targetSAMAccountName} -server $targetDC -Properties ObjectSID, SidHistory
        if(-not $targetADObject)
        {
            throw "[$targetSAMAccountName] does not exist on [$targetDC]"
        }

    Write-Verbose "Get SID Cloner tool from MS"
        $url = "https://raw.githubusercontent.com/elongstreet88/sidhistory_cloner/master/SIDCloner%20-%20add%20sIDHistory%20from%20PowerShell.zip"
        $sidCloneZip = "$($env:temp)\SIDCloner - add sIDHistory from PowerShell.zip"
        $sidClonePath = (mkdir "$($env:temp)\SIDCloner" -Force).fullname
        (New-Object System.Net.WebClient).DownloadFile($url, $sidCloneZip)
        Expand-Archive -Path $sidCloneZip -DestinationPath $sidClonePath -force
        $sidClonerDLLPath = "$($sidClonePath)\C++\x64\Release\SIDCloner.dll"
        if(-not (test-path $sidClonerDLLPath))
        {
            throw "Unable to get sid clone dll"
        }

    Write-Verbose "Verifing DLL can load (sometimes AV can block this, may have to turn off temporarily)"
        [System.Reflection.Assembly]::LoadFrom($sidClonerDLLPath) |out-null

    Write-Host "Migrating Sid History: [$($sourceDomain)\$sourceSAMAccountName] -> [$($targetDomain)\$targetSAMAccountName]"
        [wintools.sidcloner]::CloneSid( 
            $sourceSAMAccountName,
            $sourceDomain,
            $sourceDC,
            $sourceCredential.UserName,
            $sourceCredential.Password,
            $targetSAMAccountName,
            $targetDomain,
            $targetDC,
            $targetCredential.UserName, 
            $targetCredential.Password 
        )

    Write-Verbose "Verifying SID History Migrated"
        $sourceADObject = get-adobject -filter {samaccountname -eq $sourceSAMAccountName} -server $sourceDC -Properties ObjectSID, SidHistory
        $targetADObject = get-adobject -filter {samaccountname -eq $targetSAMAccountName} -server $targetDC -Properties ObjectSID, SidHistory

        if(-not $targetADObject.sIDHistory.contains($sourceADObject.objectsid))
        {
            throw "SID history migration did not appear to work"
        }
}
catch
{
	return $_
}
finally
{
}
