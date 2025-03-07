#Install-Module -Name Microsoft.Entra -Repository PSGallery -Scope CurrentUser -Force -AllowClobber



# Function to get all members of a security group, including nested groups
function Get-GroupMembers {
    param (
        [string]$GroupId
    )
 
    $members = Get-AzADGroupMember -GroupObjectId $GroupId
   
    foreach ($member in $members) {
       
        #Write-Host $member.DisplayName $member.OdataType
        if ($member.OdataType -eq "#microsoft.graph.group") {
            Write-Host "Nested Group :" + $member.DisplayName
            $nestedMembers = Get-GroupMembers -GroupId $member.Id
            Write-Host $nestedMembers.UserPrincipalName
            $members += $nestedMembers
         }
      
    }
    #filter out the list to user items only
    $eligiblemembers = $members | Where-Object {$_.OdataType -eq "#microsoft.graph.user"}

   
    return $eligiblemembers
}

# Function to synchronize Entra security group with Teams group
function Sync-EntraGroupToTeams {
    param (
        [array]$EntraGroupIds,
        [string]$TeamsGroupId
    )

    foreach($GroupId in $EntraGroupIds)
    {
        $entraMembers += Get-GroupMembers -GroupId $GroupId
    }
    # Get all members of the Entra security group
    #$entraMembers = Get-GroupMembers -GroupId $EntraGroupId

    foreach($me in $entraMembers)
    {
        Write-Host "Found" $me.DisplayName , $me.Id, $me.OdataType
    }


    $teamsMembers = Get-GroupMembers -GroupId $TeamsGroupId

    # uses MS Graph session, via interactive logon to just run in terminal
    Connect-MgGraph -Scopes "User.Read.All", "Group.ReadWrite.All"

    #Add members to Teams group
    foreach ($member in $entraMembers) {
        
        if ($teamsMembers.UserPrincipalName -notcontains $member.UserPrincipalName) {
            #Add-TeamUser -GroupId $TeamsGroupId -User $member.UserPrincipalName
            Write-Host "Adding :" $member.DisplayName
            Add-EntraGroupMember -GroupId $TeamsGroupId -MemberId $member.Id
        }
    }

    # Remove members from Teams group who are not in Entra group
    foreach ($member in $teamsMembers) {
       Write-Host "Team Member found "
        if ($entraMembers.UserPrincipalName -notcontains $member.UserPrincipalName) {
            Write-Host "Removing :" $member.DisplayName
            Remove-EntraGroupMember -GroupId $TeamsGroupId -MemberId $member.Id
        }
    }
}

## This script takes a list of Entra security group and map it to a defined M365 security group

# Replace with your Entra security group ID and Teams group ID
#$EntraGroupId = "b00cf308-c37f-46cb-8c46-36da15eca5c4"
$TeamsGroupId = "d8712f56-7c01-4c9d-bac4-a902738ab22b"

$EntraGroupId = @('b00cf308-c37f-46cb-8c46-36da15eca5c4','b4688a9a-5998-46ba-ad97-fcbc8a186d4e')
#Connect-AzAccount 
# Run the synchronization
Sync-EntraGroupToTeams -EntraGroupId $EntraGroupId -TeamsGroupId $TeamsGroupId
