#
# SELECT resources with no tags and unused for last x days (App Services & VM only)
# Input:
#       SubscriptionId
#       Resource Group
#       Days
# Assumptions:
# 1. If no tags are defined for any resource, it will be reported as NO TAGS
# 2. If there is a tag "wk_expirydate" with a valid date (mm/dd/yyyy) and that date has been passed, the resource will be reported as EXPIRED
# 3. If CpuTime metric of App Service or VM is 0 consecutively for x days, it will be reported as UNUSED resource
# 
# Output: deleteresources.input.txt
# Exaample Usage:   SelectNoTagsExpiredAndUnusedResources.ps1 <subscriptionid> <resourcegroup> <days>
#
#                   SelectNoTagsExpiredAndUnusedResources.ps1 ZUSCU-GRC-RGP-D1-CTENG 60
#


Connect-AzAccount

Set-AzContext -SubscriptionId $args[0]

$resources = Get-AzResource -ResourceGroupName $args[1]

$endTime = Get-Date
$startTime = ($endTime).AddDays(-$args[2])

foreach($resource in $resources)
{
    # validate tags 
    if($resource.Tags.Count -lt 1)
    {
        # there are no tags attached to the resoruces, report this resource
        Write-Output 'There are NO TAGS defined for '$resource.Name'(Type: '$resource.Type' Id: '$resource.Id')' 
        Add-Content .\deleteresources.input.txt "# There are NO TAGS defined for $resource.Name(Type: $resource.Type Id: $resource.Id)"
        Add-Content .\deleteresources.input.txt $resource.Id

    }
    if($resource.Tags.Count -gt 0)
    {
        foreach($key in $resource.Tags.Keys)
        {
            if($key -eq "wk_expirydate")
            {
                $currentDate = Get-Date
                $expiryDate = [datetime]::ParseExact($resource.Tags[$key], "MM/dd/yyyy", $null) ;
                if($currentDate -gt $expiryDate)
                {
                    Write-Output 'Resource EXPIRED, '$resource.Name'(Type: '$resource.Type' Id: '$resource.Id').' 
                    Add-Content .\deleteresources.input.txt "# Resource EXPIRED, $resource.Name(Type: $resource.Type Id: $resource.Id)." 
                    Add-Content .\deleteresources.input.txt $resource.Id
                }
            }
        }
    }

    # resource type specific checks
    if($resource.Type -eq "Microsoft.Web/sites")
    {
        $ok=$false;
        $metrics = Get-AzMetric -ResourceId $resource.Id -TimeGrain 1.00:00:00 -StartTime $startTime -EndTime $endTime
        foreach($metric in $metrics)
        {
            if($metric.Name.Value -eq "CpuTime")
            {
                foreach($data in $metrics.Data)
                {
                    if($data.Total -gt 0) 
                    {
                        $ok=$true    
                    }
                }
            }
        }
        if($ok -eq $false) 
        {
            Write-Output 'UNUSED app service resource, '$resource.Name'(Type: '$resource.Type' Id: '$resource.Id').' 
            Add-Content .\deleteresources.input.txt "# UNUSED app service resource, $resource.Name(Type: $resource.Type Id: $resource.Id)."
            Add-Content .\deleteresources.input.txt $resource.Id
        }
    } # ends Microsoft.Web/sites
    elseif($resource.Type -eq "Microsoft.Compute/virtualMachines")
    {
        $ok=$false;
        $metrics = Get-AzMetric -ResourceId $resource.Id -TimeGrain 1.00:00:00 -StartTime $startTime -EndTime $endTime
        foreach($metric in $metrics)
        {
            if($metric.Name.Value -eq "CpuTime")
            {
                foreach($data in $metrics.Data)
                {
                    if($data.Total -gt 0) 
                    {
                        $ok=$true    
                    }
                }
            }
        }
        if($ok -eq $false) 
        {
            Write-Output 'UNUSED virtual machine resource, '$resource.Name'(Type: '$resource.Type' Id: '$resource.Id').' 
            Add-Content .\deleteresources.input.txt "# UNUSED virtual machine resource, $resource.Name(Type: $resource.Type Id: $resource.Id)."
            Add-Content .\deleteresources.input.txt $resource.Id
        }
    } # ends Microsoft.Compute/virtualMachines

}

