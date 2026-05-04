#####################################################
# HelloID-Conn-Prov-Notification-Atlassian-Jira
# Powershell Notification system
#####################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Build a hashtable with all variables needed for the template, this can be used in the template to fill in the details of the notification.
$account = @{
    startDate = Format-Date $personContext.Person.PrimaryContract.StartDate -InputFormat 'MM/dd/yyyy hh:mm:ss' -OutputFormat "dd MMMM yyyy"
    endDate   = Format-Date $personContext.Person.PrimaryContract.EndDate -InputFormat 'MM/dd/yyyy hh:mm:ss' -OutputFormat "dd MMMM yyyy"
}

#region functions
function New-AuthorizationHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory)]
        [string]
        $username,
        
        [parameter(Mandatory)]
        [string]
        $password
    )
    try {    
        #Add the authorization header to the request
        Write-Verbose 'Adding Authorization headers'

        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $pair = $username + ":" + $password
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{
            "authorization" = $key
            "Accept"        = "application/json"
            "Content-Type"  = "application/json"
        } 

        Write-Output $headers  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-ProjectId {
    param(
        [System.Collections.IDictionary]
        $headers
    )

    $splatParams = @{
        Uri         = "$($actionContext.Configuration.url)/rest/servicedeskapi/servicedesk"
        Method      = 'GET'
        ContentType = 'application/json'
        Headers     = $headers
    }

    $response = Invoke-RestMethod @splatParams

    $responseValue = $response.values | Where-Object { $_.projectKey -eq $actionContext.TemplateConfiguration.projectid }
    
    Write-Output $responseValue
}

function Get-RequestTypeId {
    param(
        [System.Collections.IDictionary]
        $headers,

        [string]
        $projectId
    )

    $splatParams = @{
        Uri         = "$($actionContext.Configuration.url)/rest/servicedeskapi/servicedesk/$projectId/requesttype"
        Method      = 'GET'
        ContentType = 'application/json'
        Headers     = $headers
    }

    $response = Invoke-RestMethod @splatParams
    
    $responseValue = $response.values | Where-Object { $_.name -eq $actionContext.TemplateConfiguration.requestType }
    
    Write-Output $responseValue
}

function Get-VariablesFromString {
    param(
        [string]
        $string
    )    
    $regex = [regex]'\$\((.*?)\)'
    $variables = [System.Collections.Generic.list[object]]::new()

    $match = $regex.Match($string)    
    while ($match.Success) {        
        $variables.Add($match.Value)
        $match = $match.NextMatch()
    }    
    Write-Output $variables
}

function Resolve-Variables {
    param(
        [ref]
        $String,

        $VariablesToResolve
    )
    foreach ($var in $VariablesToResolve | Select-Object -Unique) {
        ## Must be changed When changing the the way of lookup variables.
        $varTrimmed = $var.trim('$(').trim(')')
        $Properties = $varTrimmed.Split('.')

        $curObject = (Get-Variable ($Properties | Select-Object -First 1)  -ErrorAction SilentlyContinue).Value
        $Properties | Select-Object -Skip 1 | ForEach-Object {
            if ($_ -ne $Properties[-1]) {
                $curObject = $curObject.$_
            }
            elseif ($null -ne $curObject.$_) {
                $String.Value = $String.Value.Replace($var, $curObject.$_)
            }
            else {
                Write-Verbose  "Variable [$var] not found"
                $String.Value = $String.Value.Replace($var, $curObject.$_) # Add to override unresolved variables with null
            }
        }
    }
}

function Format-Description {
    param (
        [ValidateNotNullOrEmpty()]
        [string]
        $Description
    )
    try {
        $variablesFound = Get-VariablesFromString -String $Description
        Resolve-Variables -String ([ref]$Description) -VariablesToResolve $variablesFound

        Write-Output $Description
    }
    catch {
        throw $_
    }
}

function Format-Date {
    [CmdletBinding()]
    param(
        [string]$date,
        [string]$InputFormat,
        [string]$OutputFormat
    )

    try {
        if ([string]::IsNullOrWhiteSpace($date)) {
            return $null
        }

        $parsedDate = [datetime]::ParseExact(
            $date,
            $InputFormat,
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        return $parsedDate.ToString(
            $OutputFormat,
            [System.Globalization.CultureInfo]::GetCultureInfo('nl-NL')
        )
    }
    catch {
        throw "An error was thrown while formatting date: $($_.Exception.Message): $($_.ScriptStackTrace)"
    }
}
#endregion functions

try {
    $actionMessage = "retrieving headers"
    $splatHeaderParams = @{
        username = $actionContext.Configuration.username
        password = $actionContext.Configuration.password
    }
    $headers = New-AuthorizationHeaders @splatHeaderParams

    if ($actionContext.TemplateConfiguration.scriptFlow -eq "Ticket") {       
        $actionMessage = "submitting ticket in Jira Cloud"
        # build the ticketObject
        $ticketObject = @{
            fields = @{
                project     = @{
                    key = $actionContext.TemplateConfiguration.projectid
                }
                summary     = Format-Description -description $actionContext.TemplateConfiguration.summary                   
                description = Format-Description -description $actionContext.TemplateConfiguration.description 
                issuetype   = @{
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
        
        if (-Not($actionContext.DryRun -eq $true)) {
            $response = Invoke-RestMethod @splatParam
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Successfully submitted a ticket [$($response.id)] for person [$($personContext.Person.DisplayName)]"
                    IsError = $false
                })
        }
        else {
            Write-Warning "DryRun: Sending notification [$($actionContext.TemplateConfiguration.scriptFlow)] for: [$($personContext.Person.DisplayName)], will be executed during enforcement"
        }
    }
    elseif ($actionContext.TemplateConfiguration.scriptFlow -eq "ServiceManagement") {
        $actionMessage = "retrieving projectId"
        $splatProjectParams = @{
            Headers = $headers
        }    
        $project = Get-ProjectId @splatProjectParams

        $actionMessage = "retrieving requestTypeId"
        $splatRequestTypeParams = @{
            Headers   = $headers
            ProjectId = $project.id
        }
        $requestType = Get-RequestTypeId @splatRequestTypeParams

        $actionMessage = "submitting ticket in Service Management"
        # build the ticketObject
        $ticketObject = @{
            serviceDeskId      = "$($project.id)"
            requestTypeId      = "$($requestType.id)"
            requestFieldValues = @{
                summary     = Format-Description -description $actionContext.TemplateConfiguration.summary                   
                description = Format-Description -description $actionContext.TemplateConfiguration.description            
            }
        }
        
        $splatParam = @{
            Uri         = "$($actionContext.Configuration.url)/rest/servicedeskapi/request"
            Method      = 'POST'
            ContentType = 'application/json'
            Body        = ([System.Text.Encoding]::UTF8.GetBytes(($ticketObject | ConvertTo-Json)))
            Headers     = $headers
        }

        if (-Not($actionContext.DryRun -eq $true)) {
            $response = Invoke-RestMethod @splatParam
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Successfully submitted a ticket [$($response.issueKey)] for person [$($personContext.Person.DisplayName)]"
                    IsError = $false
                })           
        }
        else {            
            Write-Warning "DryRun: Sending notification [$($actionContext.TemplateConfiguration.scriptFlow)] for: [$($personContext.Person.DisplayName)], will be executed during enforcement"                   
        }        
    }
    else {
        throw "Incorrect scriptFlow"
    }
    $outputContext.Success = $true
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {

        if (-Not [string]::IsNullOrEmpty($ex.ErrorDetails.Message)) {
            $errorMessage = "Error $actionMessage. Error: $($ex.ErrorDetails.Message)"
        }
        else {
            $errorMessage = "Error $actionMessage. Error: $($ex.Exception.Message)"
        }
    }
    else {
        $errorMessage = "Error $actionMessage. Error: $($ex.Exception.Message) $($ex.ScriptStackTrace)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "$errorMessage"
            IsError = $true
        })
}

