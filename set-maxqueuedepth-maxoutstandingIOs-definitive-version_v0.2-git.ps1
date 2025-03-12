#Requires -RunAsAdministrator
#Requires -Modules Vmware.VimAutomation.Core

<#
.Synopsis
  Set Max Outstanding IO on VMFS devices
.DESCRIPTION
   Set Max Outstanding IO on VMFS devices
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet

Based on these articles:

#https://community.broadcom.com/vmware-cloud-foundation/discussion/how-to-set-max-outstanding-disk-requests-to-new-lower-value
#https://community.broadcom.com/vmware-cloud-foundation/discussion/set-queue-depth-to-all-the-devices
#https://community.broadcom.com/vmware-cloud-foundation/discussion/how-to-set-max-outstanding-disk-requests-to-new-lower-value
#https://support.purestorage.com/bundle/m_howtos_for_vmware_solutions/page/Solutions/VMware_Platform_Guide/How-To_s_for_VMware_Solutions/Virtual_Volume_How_To_s/topics/task/t_updating_the_protocol_endpoint_no_of_outstanding_ios.html


Pre requirements

#Instal PowerCli version 11 or superior

#Find me at (julianoalvesbr@live.com or https://github.com/julianoabr)
#Version 0.1
#Environment: Production
#>


$vmHost = 'yourhost.yourdomain.com'

$dsNameList = @()

$dsNameList = (get-datastore | Where-Object -FilterScript {$PSItem.ExtensionData.Summary.MultipleHostAccess -eq $true -and $PSItem.Name -notlike '*CLUSTERED*'}) | Select-Object -ExpandProperty Name | Sort-Object

[System.String]$newMaxIOValue = '128'

foreach ($dsName in $dsNameList)
{
    
    $dsObj = Get-datastore -Name $dsName

    $dsNAA = $dsObj.ExtensionData.Info.Vmfs.Extent.DiskName
    
    $esxObj = Get-VMHost -Name $vmHost

    $esxcli = Get-EsxCli -VMHost $esxObj -V2
    
    #For Test Purpose Only
    #$dsNAA = 'naa.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

    $dsNAAObj = $esxcli.storage.core.device.list.Invoke() | Where {$_.Device -match $dsNAA}
    
    if($dsNAAObj.NoofoutstandingIOswithcompetingworlds -ne $newMaxIOValue){

        $objSetValue = $esxcli.storage.core.device.set.CreateArgs()

        $objSetValue.device = $dsNAAObj.Device

        $objSetValue.schednumreqoutstanding = $newMaxIOValue

        $esxcli.storage.core.device.set.Invoke($objSetValue)
          
        #get new value
        $objGetValue = $esxcli.storage.core.device.list.CreateArgs()

        $objGetValue.device = $dsNAAObj.Device

        $esxcli.storage.core.device.list.Invoke($objGetValue) | Select Device,NoofoutstandingIOswithcompetingworlds

            Write-Host "LUN with Name: $dsName and NAA: $dsNAA on Host: $vmHost has outstanding IO value set to 128" -ForegroundColor White -BackgroundColor Green

        }#end of IF

        else{

            Write-Host "LUN with Name: $dsName and NAA: $dsNAA on Host: $vmHost has already outstanding IO value set to 128" -ForegroundColor White -BackgroundColor DarkBlue

        }#end of Else


}#end of ForEach



