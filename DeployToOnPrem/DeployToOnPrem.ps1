param(
    $BCVersion,
    $BCInstance,
    $appName,
    $token,
    $branch,
    $syncMode,
    $uninstallMode,
    $aadTenantId
)

function importModuleWithTestPath
{
    Param (
        [string] $modulePath
    )
    
    if (Test-Path $modulePath) {
        Import-Module $modulePath -WarningAction SilentlyContinue | Out-Null 
    } else {
        throw "Could not find $modulePath"
    }
}

function testOption
{
    Param (
        [array] $optionList,
        [string] $optionValue
    )

    if ($optionList -notcontains $optionValue) {
        throw "Undefined option $optionValue, allowed values are $optionList"
    }
}

# test syncMode, uninstallMode Parameter
testOption "Add","ForceSync" $syncMode
testOption "DoNotSaveData","ClearSchema","SaveData","" $modeArray

# extract appname from GITHUB_REPOSITORY if not specified in ALDEVOPS_SETTINGS
$AppName = $AppName.Substring($AppName.IndexOf('/')+1)
$appPublisher = '*'
 
# import NavAdmin module
$navAdminToolPath = $ENV:ProgramFiles + '\Microsoft Dynamics 365 Business Central\' + $BCVersion + '0\Service\NavAdminTool.ps1'
importModuleWithTestPath $navAdminToolPath

# test bcinstance (NST)
$navServerServiceName =  "MicrosoftDynamicsNavServer`$" + $BCInstance;
try {
    $nstStatus = (get-service "$navServerServiceName").Status;
    if ($nstStatus -ne 'Running') {
        throw "$navServerServiceName service not running"
    }
} catch {
    throw "$navServerServiceName service not installed"
}

# create dynamic module from microsoft/AL-GO script block Github-Helper.psm1 (functions are immediately available in the session)
$URL = 'https://raw.githubusercontent.com/microsoft/AL-Go-Actions/main/Github-Helper.psm1'
try{
    New-Module -Name "$URL" -ScriptBlock ([Scriptblock]::Create((New-Object System.Net.WebClient).DownloadString($URL))) -ErrorAction SilentlyContinue > $null
}catch{
    Write-Verbose "Import-Module Failed to Import Github-Helper.psm1"
}

# create artifacts folder
$baseFolder = Join-Path $ENV:GITHUB_WORKSPACE ".artifacts"
if (!(Test-Path $baseFolder)) {
    New-Item $baseFolder -ItemType Directory | Out-Null
}
$baseFolderCreated = $true

# get artifacts
$allArtifacts = @(GetArtifacts -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY -mask "Apps" -projects '*' -Version '*' -branch $branch)
if ($allArtifacts) {
    $allArtifacts | ForEach-Object {
        $artifactFile = DownloadArtifact -token $token -artifact $_ -path $baseFolder
        if (!(Test-Path $artifactFile)) {
            throw "Unable to download artifact $($_.name)"
        }
        if ($artifactFile -notlike '*.zip') {
            throw "Downloaded artifact is not a .zip file"
        }

        # expand archive and delete zip
        $destinationPath = ($artifactFile.SubString(0,$artifactFile.Length-4))
        Expand-Archive -Path $artifactFile -DestinationPath $destinationPath -Force
        Remove-Item $artifactFile -Force
        
        # Search file in expandfolder with masked publisher and version, because new version depends on version strategie
        $mainAppFileName = $($appPublisher) + ("_$($appName)_".Split([System.IO.Path]::GetInvalidFileNameChars()) -join '') + "*.*.*.*.app"

        $appFile = Get-ChildItem -path $destinationPath | Where-Object { $_.name -like $mainAppFileName } | ForEach-Object { $_.FullName }
        if (!(Test-Path $appFile)) {
            throw "Could not find $appFile"
        }
        
        Write-Host "`nDeploying Solution"
        # publish
        # first install, reinstall with same version, update to newer version, uninstall delete app data, uninstall clear (to lower version), sync add or force
        $skipDataupgrade = $false
        $UnpublisedApps = 'false'
        $UnpublishedVersion = ''
        $runner = 1
        $Apps = Get-NAVAppInfo -ServerInstance $BCInstance -TenantSpecificProperties -name $appName -Tenant 'default' | Where-Object { $_.IsPublished }
        foreach ($App in $Apps) {
            Write-Host "$("{0:d2}" -f $runner): uninstalling $($App.Name), $($App.Version) from $BCInstance"
            if ($App.IsInstalled) {
                Write-Host "... uninstall $uninstallMode"
                switch ($uninstallMode)
                {
                    DoNotSaveData {
                        Uninstall-NAVApp -ServerInstance $BCInstance -Name $App.Name -Version $App.Version -Force -DoNotSaveData
                        $SkipDataUpgrade = $true
                    }
                    ClearSchema {
                        Uninstall-NAVApp -ServerInstance $BCInstance -Name $App.Name -Version $App.Version -Force -ClearSchema
                        $SkipDataUpgrade = $true
                    }
                    default { 
                        Uninstall-NAVApp -ServerInstance $BCInstance -Name $App.Name -Version $App.Version -Force
                    }
                }
            }
            Write-Host '... unpublish'
            UnPublish-NAVApp -ServerInstance $BCInstance -Name $App.Name -Version $App.Version
            $UnpublisedApps = $true
            $UnpublishedVersion = $App.Version
            $runner += 1
        }

        #$value = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($aadTenantId))
        $value = $aadTenantId
    
        if ($value) {
            Write-Host "Tenant=$($value)"
        } else {
            Write-Host "no Tenant spec"
        }

        #if ($aadTenantId) {
        #    Publish-NAVApp -ServerInstance $BCInstance -Path $appFile -SkipVerification -scope Tenant -PublisherAzureActiveDirectoryTenantId $aadTenantId
        #} else {
            Publish-NAVApp -ServerInstance $BCInstance -Path $appFile -SkipVerification -scope Tenant
        #}
        $App = Get-NAVAppInfo -ServerInstance $BCInstance -TenantSpecificProperties -name $appName -Tenant 'default' | Where-Object { $_.IsPublished }
        Write-Host "$("{0:d2}" -f $runner): publishing $($App.Name), $($App.Version) to $BCInstance"
        Write-Host '... publish'
        if ($App.SyncState -ne 'Synced') {
            Write-Host "... sync $syncMode"
            Sync-NAVApp -ServerInstance $BCInstance -Name $App.Name -Mode $syncMode -Version $App.Version -Force
        }
        if (($UnpublisedApps -eq $true) -and ($skipDataupgrade -eq $false) -and (($UnpublishedVersion -ne $App.Version))) {
            Write-Host '... Start-NAVAppDataUpgrade'
            Start-NAVAppDataUpgrade -ServerInstance $BCInstance -Name $App.Name -Version $App.Version
        } else {
            Write-Host '... Install-NAVApp'
            Install-NAVApp -ServerInstance $BCInstance -Name $App.Name -Version $App.Version
        }
    }
}
else {
    throw "Could not find any Apps artifacts"
}

# delete .artifact folder after deploy
if ($baseFolderCreated) {
    Remove-Item $baseFolder -Recurse -Force
}
