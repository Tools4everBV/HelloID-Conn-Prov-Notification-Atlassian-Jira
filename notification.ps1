#####################################################
# HelloID-Conn-Prov-Notification-Atlassian-Jira
#
# Version: 1.0.0 | new-powershell-connector
#####################################################

# Set to true at start, because only when an error occurs it is set to false
$outputContext.Success = $true

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function New-AuthorizationHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory)]
        [string]
        $username,

        [parameter(Mandatory)]
        [SecureString]
        $password
    )
    try {    
        #Add the authorization header to the request
        Write-Verbose 'Adding Authorization headers'

        $passwordToUse = $password | ConvertFrom-SecureString -AsPlainText

        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $pair = $username + ":" + $passwordToUse
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{
            "authorization" = $Key
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        } 

        Write-Output $headers  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion functions

try {
    [SecureString]$securePassword = ConvertTo-SecureString $actionContext.Configuration.password -AsPlainText -Force
    $headers = New-AuthorizationHeaders -username $actionContext.Configuration.username -password $securePassword

    if (-Not($actionContext.DryRun -eq $true)) {
        # Write notification logic here

        if ($actionContext.TemplateConfiguration.scriptFlow -eq "Ticket") {
            # build the ticketObject
            $ticketObject = @{
                fields = @{
                    project = @{
                        key = $actionContext.TemplateConfiguration.projectid
                    }
                    summary = $actionContext.TemplateConfiguration.summary
                    description = $actionContext.TemplateConfiguration.description
                    issuetype = @{
                        name = $actionContext.TemplateConfiguration.issuetype
                    }
                }
            }

            $splatParam = @{
                Uri         = "$($actionContext.Configuration.url)/rest/api/latest/issue"
                Method      = 'POST'
                ContentType = 'application/json'
                Body        = ([System.Text.Encoding]::UTF8.GetBytes(($ticketObject | ConvertTo-Json)))
                Headers     = $headers
            }
        
            $response = Invoke-RestMethod @splatParam

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = "Successfully submitted a ticket [$($response.id)] for person $($personContext.Person.DisplayName)'"
                IsError = $false
            })
        } else {
            # Execute script flow two
        }
    } else {
        # Add an auditMessage showing what will happen during enforcement
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "DryRun: Sending notification [$($actionContext.TemplateConfiguration.scriptFlow)] for: [$($personContext.Person.DisplayName)], will be executed during enforcement"
        })
        Write-Verbose ($ticketObject | ConvertTo-Json)
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {

        if (-Not [string]::IsNullOrEmpty($ex.ErrorDetails.Message)) {
            $errorMessage = "Could not $action account. Error: $($ex.ErrorDetails.Message)"
        }
        else {
            $errorMessage = "Could not $action account. Error: $($ex.Exception.Message)"
        }
    }
    else {
        $errorMessage = "Could not $action account. Error: $($ex.Exception.Message) $($ex.ScriptStackTrace)"
    }

    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Message = "Error occurred submitting ticket [$($actionContext.TemplateConfiguration.scriptFlow)] for: [$($personContext.Person.DisplayName)], Error: $errorMessage"
        IsError = $true
    })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if ($outputContext.AuditLogs.isError -contains $true) {
        $outputContext.Success = $false
    }
}

