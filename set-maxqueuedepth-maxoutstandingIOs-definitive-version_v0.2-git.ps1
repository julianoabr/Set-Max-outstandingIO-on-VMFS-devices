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
#https://knowledge.broadcom.com/external/article/323119/changing-the-queue-depth-for-qlogic-emul.html
#https://virtuallyjason.blogspot.com/2013/11/powercli-scripting-to-set-queue-full.html
#https://poweradm.com/change-hba-queue-depth-vmware-esxi/
#https://www.cisco.com/c/pt_br/support/docs/servers-unified-computing/vmware-esxi-cisco-ucs/214808-configuring-the-queue-depth-of-the-nfnic.pdf

Pre requirements

#Instal PowerCli version 11 or superior

#Find me at (julianoalvesbr@live.com or https://github.com/julianoabr)
#Version 0.1
#Environment: Production
#>

#Input the ESXi Host Name
$esxiHost = 'fqdn.or.ip.address.of.host.to.be.changed'

$esxObj = Get-VMHost -Name $esxiHost

$esxcli = Get-EsxCli -VMHost $esxObj -V2


#Get the HBA Module Driver (valid only for FC) 
$hbaModuleDriver = $esxcli.storage.core.adapter.list.Invoke() | Where-Object -FilterScript {$PSItem.UID -like '*fc*'} | Select-Object -ExpandProperty Driver | Select-Object -First 1

#Get the current value of HBA System Module Driver
$arguments = $esxcli.system.module.parameters.list.CreateArgs()

$arguments.module = $hbaModuleDriver

$esxcli.system.module.parameters.list.Invoke($arguments)

Write-Output "Value of LUn Queue Depth for ESXi: $esxiHost"

$esxcli.system.module.parameters.list.Invoke($arguments) | Where-Object -FilterScript {$PSItem.Name -eq 'lun_queue_depth_per_path'} | Select-Object -Property Name,Type,Value


#Set the value of HBA System Module Driver to 128
$Parameters = $esxcli.system.module.parameters.set.CreateArgs()

$Parameters.module = $hbaModuleDriver

$Parameters.parameterstring = ‘lpfc_lun_queue_depth=128’

$esxcli.system.module.parameters.set.Invoke($Parameters)

#Get Shared Datastore List
$dsNameList = @()

$dsNameList = (Get-datastore | Where-Object -FilterScript {$PSItem.ExtensionData.Summary.MultipleHostAccess -eq $true -and $PSItem.Name -notlike '*CLUSTERED*' -and $PSItem.Type -eq 'VMFS'}) | Select-Object -ExpandProperty Name | Sort-Object

$dsNameListTotal = $dsNameList.Count

Write-Host "I found $dsNameListTotal Datastore with selected criteria" -ForegroundColor White -BackgroundColor Green

#Desired Outstanding IO Value
[System.String]$newMaxIOValue = '128'


#Now the Outstanding IO value can be set on the PE Device, as it's default will still be 32. 
foreach ($dsName in $dsNameList)
{
    
    $dsObj = Get-datastore -Name $dsName

    $dsNAA = $dsObj.ExtensionData.Info.Vmfs.Extent.DiskName
    
    $esxObj = Get-VMHost -Name $esxiHost

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

            Write-Host "LUN with Name: $dsName and NAA: $dsNAA on Host: $esxiHost has outstanding IO value set to 128" -ForegroundColor White -BackgroundColor Green

        }#end of IF

        else{

            Write-Host "LUN with Name: $dsName and NAA: $dsNAA on Host: $esxiHost has already outstanding IO value set to 128" -ForegroundColor White -BackgroundColor DarkBlue

        }#end of Else


}#end of ForEach
