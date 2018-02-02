 # This script can be used to get the "recommended datastore" for a particular VMware datastore cluster as part of a VM deployment process. 
# Notes are currently written to have it run as a runbook in Microsoft System Center Orchestrator.

# Set script parameters from runbook data bus and Orchestrator global variables
$vCenter = "insert value"
$OrchestratorUser = "insert value"
$OrchestratorPassword = "insert value"
$datastoreClusterName = "insert value"
$newVMName = "insert value"
$templateName = "insert value"
$DatacenterID = "insert value"
$ServerName = "insert value"
$ResultStatus = ""
$ErrorMessage = ""

　
try
{

#Set Logging
. "insert path here\Loggingscript.ps1"
$LogfileName = $ServerName + "_" + (Get-Date -Format "MM-dd-yyyy") + ".log"
$LogfilePath = "insert path here\$LogfileName"

write-log -path $LogfilePath -Message "The Get Datastore in DSC runbook is starting."

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
            throw "ERROR: Failed to connect to vCenter server [$vCenter]"
          }  

          else
          {

       $datastoreCluster = Get-DatastoreCluster $datastoreClusterName;
       if ($datastoreCluster)
       {
        $pod = $datastoreCluster.ExtensionData.MoRef;
        
        if($pod)
        {
            $folder = (get-view -viewtype Folder | Where {$_.Name -eq 'vm'} | Where {$_.Parent -eq $DatacenterID})[0].MoRef;

            if($folder)
            {
                $template = (Get-View -ViewType "VIRTUALMACHINE" -Filter @{Name=$templateName} | Where {$_.Name -eq $templateName})[0].MoRef;

                if($template)
                {
                    $storagePod = New-Object VMware.Vim.StorageDrsPodSelectionSpec -Property @{StoragePod=$pod};
                    
                   $hosts = $datastoreCluster | Get-VMHost;
                   $location = New-Object VMWare.Vim.VirtualMachineRelocateSpec -Property @{Host=$hosts[0].ExtensionData.MoRef};  
                   
                   $cloneSpec = New-Object VMWare.Vim.VirtualMachineCloneSpec -Property @{PowerOn=$false;Template=$false;Location=$location};

                    $storageSpec = New-Object VMware.Vim.StoragePlacementSpec -Property @{type='clone';cloneName=$newVMName;folder=$folder;podSelectionSpec=$storagePod;vm=$template;cloneSpec=$cloneSpec};

                    if($storageSpec)
                    {
                        $storageManager = (Get-View StorageResourceManager);

                        if($storageManager)
                        {
                            $recommendations = $storageManager.RecommendDatastores($storageSpec);

                            if(($recommendations.Recommendations) -and ($recommendations.Recommendations.Count -gt 0)) 
                            { 
                            $dsrecommendation = $recommendations.Recommendations[0].Action[0].Destination; 
                            $dsrecommendation = (get-datastore -Id "datastore-$($dsrecommendation.value)").name
                            $ResultStatus = "Success"
                            write-log -path $LogfilePath -Message "Datastore chosen for $ServerName - $dsrecommendation."
                            write-log -path $LogfilePath -Message "The Get Datastore in DSC runbook completed with a ResultStatus of $ResultStatus."
                            }

                            else { throw: "Error: Unable to get datastore recommendation for $datastoreClusterName"; }
                        }
                        else { throw: "Error: Unable to get the StorageManager to determine recommended datastore for $datastoreClusterName"; }
                    }
                    else { throw: "Error: Unable to create the StorageSpec to determine recommended datastore for $datastoreClusterName"; }
                }
                else { throw: "Error: Unable to find the Template VM $templateName to determine recommended datastore for $datastoreClusterName"; }
            }
            else { throw: "Error: Unable to find the VM folder to determine recommended datastore for $datastoreClusterName"; }
        }
        else { throw: "Error: Unable to get the DRSSpec to determine recommended datastore for $datastoreClusterName"; }
    }
    else { throw: "Unable to find the DatastoreCluster: $datastoreClusterName to determine recommended datastore"; }
}
}

catch
{
    # Catch any errors thrown above, set result status.
    $ResultStatus = "Failed"
    $ErrorMessage = $error[0].Exception.Message
    write-log -path $LogfilePath -Message "The Get Datastore in DSC runbook completed with a ResultStatus of $ResultStatus. Error: $ErrorMessage"
} 
