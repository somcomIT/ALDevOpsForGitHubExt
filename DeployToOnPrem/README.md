# DeployToOnPrem

GitHub Action to deploy Microsoft Dynamics 365 Business Central Extension App to On-Premises environment.

The deployment will run correctly if the app is installed for the first time or upgraded with a higher version number. Publishing with the same version number is also possible, with a lower version number only if the schema and the data are deleted (ClearSchema).

Prerequisites:

* self-hosted runner
* Business Central on-premises installation
* running instance of Business Central
* existing app artifact created with AL-GO CI/CD action (latest in selected branch)

## Parameters

### token

The GitHub token running the action, not required, default = github.token

### bcVersion

Specifies the version of the BC System running i.e. 20, 21, 22, ..., required

### onPremInstance

Specifies the name of a Business Central Server instance, required

### appName

The name of the app to be deployed, extracts the name of the repository as app name if github.repository is provided (userororg/repo), 
required

### useBranch

The branch to get the desired artifacts (.app files) to deploy, required

### syncMode

Specifies how the database schema for the tenant database is synchronized with the database schema that the target Business Central app's objects define, not required, Options = "Add, ForceSync", default = Add

### uninstallMode

Specifies the usage of some optional parameters for the Uninstall-NAVApp cmdlet, not required, Options = "SaveData, DoNotSaveData, ClearSchema", default = SaveData

## Configuration with Action Variable

The following variable structure can be used to configure the different parameters of this action.

Name: ALDEVOPS_SETTINGS

```json
{
    "appname": "TheALAppName",
    "bcversion": "21",
    "environments": {
        "PROD": {
            "bcinstance" : "BC21",
            "runnergroup": "prod_client",
        },
        "TEST": {
            "bcinstance" : "BC21TEST",
            "runnergroup": "dev",
        },
        "DEV": {
            "bcinstance" : "BC21DEV",
            "runnergroup": "dev",
            "enabledatalossoptions": "true"  
        }
    }
}
```

## Runners configuration and security

The configuration of the self-hosted runners must be made with caution for security reasons. The following basic precautions should be observed:

For Runners, which are set up and installed on productive systems, the following applies:

1. Each runner should be assigned to their own group (always only one runner per group)
2. Such groups should only have access to certain repos
3. In addition, access should be restricted to one workflow (for example: *orgname/reponame/.github/workflows/PublishToOnPremEnvironment.yaml@refs/heads/main*)

The repo that has access to the workflow should have an action variable with the name ALDEVOPS_SETTINGS with a definition for the element "runnergroup" for a defined environment. So it is possible to run the publishing workflow job only if the variable is defined.
