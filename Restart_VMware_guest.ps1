 # This script can be used to restart a guest VM (leverages VMware Tools) running on a VMware ESXi host.
# Notes are written to use this script as part of a System Center Orchestrator runbook.

# Set script parameters from runbook data bus and Orchestrator global variables
$vCenter = "insert value here"
$OrchestratorUser = "insert value here"
$OrchestratorPassword = "insert value here"
$ServerName = "insert value here"
$ErrorMessage = ""
$ResultStatus = "Success"

try
{

#Set Logging
. "insert path here\Loggingscript.ps1"
$LogfileName = $ServerName + "_" + (Get-Date -Format "MM-dd-yyyy") + ".log"
$LogfilePath = "insert path here\$LogfileName"

write-log -path $LogfilePath -Message "The Restart Guest OS script is starting."

# Load PowerCLI modules
Import-Module "VMware.VimAutomation.Core"
Import-Module "VMware.VimAutomation.Vds"
Import-Module "VMware.VimAutomation.Cis.Core"
Import-Module "VMware.VimAutomation.Storage"
Import-Module "VMware.VimAutomation.HA"
Import-Module "VMware.VimAutomation.vROps"
Import-Module "VMware.VumAutomation"
Import-Module "VMware.VimAutomation.License"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings $false -WebOperationTimeoutSeconds 90 -Confirm:$false | Out-Null

# Connect to vCenter server after disconnecting any existing sessions
         if($global:DefaultVIServers) 
        {
            Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false
        }
         $vcenterServer = Connect-VIServer -Server $vCenter -User $OrchestratorUser -Password $OrchestratorPassword 

          if($vcenterServer -eq $null) 
         {
            write-log -path $LogfilePath -Message "The Restart Guest OS script failed to connect to $vCenter vCenter. The vCenter variable is null."
            throw "ERROR: Failed to connect to vCenter server [$vCenter]"
          }  

          else
          {
           
             if ($ServerName)
                {
                  get-vm $ServerName | get-vmguest | restart-vmguest -Confirm:$false
                  write-log -path $LogfilePath -Message "The Restart Guest OS script just attempted to restart $ServerName via vCenter."
                  Disconnect-VIServer -Server $vCenter -Confirm:$false
                 }
              else
                 {
                  write-log -path $LogfilePath -Message "ERROR: The ServerName variable is blank.  Value = $ServerName"
                  throw "ERROR: The ServerName variable is blank.  Value = $ServerName"
                  Disconnect-VIServer -Server $vCenter -Confirm:$false
                  }
            }
}

catch

{
        # Catch any errors thrown above, set result status.
        $ResultStatus = "Failed"
        $ErrorMessage = $error[0].Exception.Message
        write-log -path $LogfilePath -Message "The Restart Guest OS script completed with a ResultStatus of $ResultStatus. Error: $ErrorMessage"
 } 
