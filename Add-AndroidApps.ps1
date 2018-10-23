<#
.SYNOPSIS
    This is a PowerShell template.

.DESCRIPTION
    Download cmdlets: https://github.com/Microsoft/Intune-PowerShell-SDK
    Connect-MSGraph -AdminConsent
    This is a PowerShell template. This can be used to base other scripts on.
    If there are any problems with the script, please contact Orbid Servicedesk (servicedesk@orbid.be or + 32 9 272 99 00)

    This scripts creates a log file each time the script is executed.
    It deletes all the logs it created that are older than 30 days. This value is defined in the MaxAgeLogFiles variable.

.PARAMETER LogPath
    This defines the path of the logfile. By default: "C:\Windows\Temp\CustomScript\${FILE}.txt"
    You can overwrite this path by calling this script with parameter -logPath (see examples)

.EXAMPLE
    Use the default logpath without the use of the parameter logPath
    ..\${FILE}

.EXAMPLE
    Change the default logpath with the use of the parameter logPath
    ..\${FILE} -logPath "C:\Windows\Temp\Template.txt"

.NOTES
    File Name  : ${FILE}
    Author     : Thijs Lecomte
    Company    : Orbid NV
#>

#region Parameters
#Define Parameter LogPath
param (
    [string]$LogPath = "C:\Windows\Temp\CustomScripts\Add-AndroidApps.txt",
    [string]$csvLocation,
    [string]$IntuneModule
    [Char]$csvDelimiter = ";"
)
#endregion

#region variables
$MaxAgeLogFiles = 30
#endregion


#region functions
#Define Log function
Function Write-Log {
    Param ([string]$logstring)

    $DateLog = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $WriteLine = $DateLog + "|" + $logstring
    try {
        Add-Content -Path $LogPath -Value $WriteLine -ErrorAction Stop
    }
    catch {
        Start-Sleep -Milliseconds 100
        Write-Log $logstring
    }
    Finally {
        Write-Host $logstring
    }
}
#endregion


#region Log file creation
#Create Log file
try {
    #Create log file based on logPath parameter followed by current date
    $date = Get-Date -Format yyyyMMddTHHmmss
    $date = $date.replace("/", "").replace(":", "")
    $logpath = $logpath.insert($logpath.IndexOf(".txt"), " $date")
    $logpath = $LogPath.Replace(" ", "")
    New-Item -Path $LogPath -ItemType File -Force -ErrorAction Stop

    #Delete all log files older than x days (specified in $MaxAgelogFiles variable)
    try {
        $limit = (Get-Date).AddDays(-$MaxAgeLogFiles)
        Get-ChildItem -Path $logPath.substring(0, $logpath.LastIndexOf("\")) -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Log $ErrorMessage
    }
}
catch {
    #Throw error if creation of loge file fails
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup($_.Exception.Message, 0, "Creation Of LogFile failed", 0x1)
    exit
}

Function Import-IntuneModule {
    Param([String]$location)

    Write-Log "[INFO] - Starting Function Import-IntuneModule"
    Write-Log "[INFO]  - Importing module from $location"
    Try{
        Import-Module $location
        Write-Log "[INFO] - Sucessfully imported module"
    }
    Catch{
        Write-Log "[ERROR] - Import Intune Module, exiting"
        Write-Log "$($_.Exception.Message)"
        Exit
    }
    Write-Log "[INFO] - Ending Function Import-IntuneModule"
}

Function Import-CSVApplications {
    Param($Path,$csvDelimiter)
    Write-Log "[INFO] - Starting Function Import-CSVApplications"
    Write-Log "[INFO] - Starting import form $path"
    Try{
        return Import-CSV -Path $Path -Delimiter $csvDelimiter
    }
    Catch{
        Write-Log "[ERROR] - Error"
        Write-Log "$($_.Exception.Message)"
    }
    Write-Log "[INFO] - Ending Function Import-CSVApplications"
}

Function Connect-Intune {
    Write-Log "[INFO] - Starting Function Connect-Intune"
    Try{
        Connect-MSGraph
        Write-Log "[INFO] - Connected to Intune"
    }
    Catch{
        Write-Log "[ERROR] - Connecting to Graph Intune"
        Write-Log "$($_.Exception.Message)"
    }
    Write-Log "[INFO] - Ending Function Connect-Intune"
}

Function Create-Applications {
    Param([array]$applications)
    Write-Log "[INFO] - Starting Function Create-Applications"
    Write-Log "[INFO] - Will be creating $($applications.Count) application"
    foreach($application in $applications){
        Write-Log "[INFO] - Creating $($application.Name)"
        #Publishing state is required to assign apps?

        #Get icon and icontype
        $iconBytes = Get-Content $application.Icon -Encoding Byte
        $iconExt = ([System.IO.Path]::GetExtension("$application.Icon")).replace(".","")
        $iconType = "image/$iconExt"

        #Create Min operating system object
        $parameters = @{"v$($application.MininumAndroidVersion)" = $True}
        $androidVersion = New-AndroidMinimumOperatingSystemObject @parameters
        Write-Log "[INFO] - Created AndroidVersion Object $androidVersion"

        Try{
            New-DeviceAppManagement_MobileApps -androidStoreApp -displayName $Application.Name -appStoreUrl $application.URL -publisher $application.Publisher `
            -Description $application.Description -minimumSupportedOperatingSystem $androidVersion -largeIcon (New-MimeContentObject -type $iconType -value $iconBytes)
            Write-Log "[INFO] - Added application $($application.Name)"
        }
        Catch{
            Write-Log "[ERROR] - Error adding application $application"
            Write-Log "$($_.Exception.Message)"
        }
    }
    Write-Log "[INFO] - Ending Function Create-Applications"
}
#endregion

#region Operational Script
Write-Log "[INFO] - Starting script"

Import-IntuneModule -location $IntuneModule 

$applications = Import-CSVApplications -Path $csvLocation -csvDelimiter $csvDelimiter

Connect-Intune

Create-Applications -Applications $applications

Write-Log "[INFO] - Stopping script"
#endregion