# HelloID-Conn-Prov-Notification-Atlassian-Jira

| :warning: Warning                                                                                                                                                                                                                                 |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Please be aware that the current notifications only can be triggered by built-in events. For other applications please use the Target connector [HelloID Atlassian-Jira target system](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Atlassian-Jira) |


| :information_source: Information                                                                                                                                                                                                                                                                                                                                                       |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |
<br />
<p align="center"> 
  <img src="https://www.tools4ever.nl/connector-logos/atlassianjira-logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Notification-Atlassian-Jira](#helloid-conn-prov-notification-topdesk)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Templates](#templates)
      - [Tickets](#tickets)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Notification-Atlassian-Jira_ is a _notifcation_ connector. Atlassian provides a set of REST APIs that allow you to programmatically interact with its data. The [Jira API documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-i) provides details of API commands that are used.

## Getting started
### Prerequisites

  - Credentials with the rights as described in permissions

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| Jira Url | Example: https://customer.atlassian.net |
| Username | User with permissions to create ticket |
| API key | API key of the user |

More about API keys: https://id.atlassian.com/manage/api-tokens


### Templates

There is currently only one template. When configuring the tickets, make sure to provide the correct _project.key_ and the correct _issueType_.
The projects are supplied in a dropdown list in the template. Change this for each implementation. 
| :warning: Warning                                                                                                                           |
| :------------------------------------------------------------------------------------------------------------------------------------------ |
|                                                                                                                                             |
| Please keep in mind that the key form field names in the templates are used in the notification.ps1 changing them will break the connector. |

### Ticket
To create a form for tickets the following template should be used: [template.json](https://github.com/Tools4everBV/HelloID-Conn-Prov-Notification-Atlassian-Jira/blob/main/template.json).

The table below describes the different form fields from the template.

| template key             | Description                                                                      | Mandatory |
| ------------------------ | -------------------------------------------------------------------------------- | --------- |
| scriptFlow | Fixed value of Change (read-only)  | Yes |
| projectid | The project key value | Yes |
| summary | Subject of the ticket  | Yes |
| description | The body of the ticket. Variables can be used from the person model | Yes |
| issueType | Must be the exact name of the issue type | Yes |



## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/notifications--provisioning-/notification-systems--provisioning-/powershell-notification-systems--provisioning-/add,-edit,-or-remove-a-powershell-notification-system.html) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/1266-helloid-conn-prov-notification-Atlassian-Jira)_

## HelloID docs

> The official HelloID documentation can be found at: https://docs.helloid.com/