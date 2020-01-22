# DeleteResources.ps1
# DELETE azure resources contained by the input file
# Input: text file output contents from SelectNoTagsExpiredAndUnusedResources.ps1
#

Connect-AzAccount

foreach($line in [System.IO.File]::ReadLines($args[0]))
{
       if(-not($line.Substring(0,1) -eq "#")) # ignore comments
       {
           Remove-AzResource -ResourceId $line  # delete the resource with id
       }
}
