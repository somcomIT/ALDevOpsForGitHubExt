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

## Sample yaml for AL Project

### PublishToOnPremEnvironment.yaml

```yaml
name: 'Publish To On-Prem Environment'

on:
  workflow_dispatch:
    inputs:
      useBranch:
        description: Artifacts of branch to deploy (main)
        required: true
        default: 'main'
      environment:
        type: choice
        description: On-Prem Environment
        required: true
        options:
        - PROD
        - TEST
        - DEV
        default: 'TEST'
      onPremInstanceName:
        description: BC Instance (current defined in variables ALDEVOPS_SETTINGS environments[On-Prem Environment]), may be overruled here
        type: string
        required: false
      syncMode:
        type: choice
        description: Mode for schema synchronisation
        options:
        - Add
        - ForceSync
        default: 'Add'
        required: false
      uninstallMode:
        type: choice
        description: Data handling owned by the app on reinstall 
        required: false
        options:
        - SaveData
        - DoNotSaveData
        - ClearSchema
        default: 'SaveData'

permissions:
  contents: read
  actions: read

defaults:
  run:
    shell: PowerShell

env:
  _bcversion: ${{ fromJSON(vars.ALDEVOPS_SETTINGS).bcversion }}
  _bcinstance: ${{ github.event.inputs.onPremInstanceName || fromJSON(vars.ALDEVOPS_SETTINGS).environments[github.event.inputs.environment].bcinstance }}
  _enabledataloss: ${{ fromJSON(vars.ALDEVOPS_SETTINGS).environments[github.event.inputs.environment].enabledatalossoptions }}
  _appname: ${{ fromJSON(vars.ALDEVOPS_SETTINGS).appname || github.repository }}

jobs:
  Publish:
    if: ${{ vars.ALDEVOPS_SETTINGS && fromJSON(vars.ALDEVOPS_SETTINGS).environments[github.event.inputs.environment].runnergroup }}
    runs-on: 
      labels: [ self-hosted ]
      group: ${{ fromJSON(vars.ALDEVOPS_SETTINGS).environments[github.event.inputs.environment].runnergroup }}
    name: Publish to BCInstance
    steps:
      - name: Deploy keep data
        if: ${{ env._enabledataloss == 'false' || github.event.inputs.uninstallMode == 'SaveData'}}
        uses: somcomIT/ALDevOpsForGithubExt/DeployToOnPrem@v1.0
        with:
          bcVersion: ${{ env._bcVersion }}
          onPremInstanceName: ${{ env._bcinstance }}
          appName: ${{ env._appname }}
          useBranch: ${{ github.event.inputs.useBranch }}
          syncMode: ${{ github.event.inputs.syncMode }}
      - name: Deploy delete data
        if: ${{ env._enabledataloss == 'true' && github.event.inputs.uninstallMode != 'SaveData'}}
        uses: somcomIT/ALDevOpsForGithubExt/DeployToOnPrem@v1.0
        with:
          bcVersion: ${{ env._bcVersion }}
          onPremInstanceName: ${{ env._bcinstance }}
          appName: ${{ env._appname }}
          useBranch: ${{ github.event.inputs.useBranch }}
          syncMode: ${{ github.event.inputs.syncMode }}
          uninstallMode: ${{ github.event.inputs.uninstallMode }}
```

### Configuration Action Variable

Name: ALDEVOPS_SETTINGS

```
{
    "appname": "TheALAppName",
    "bcversion": "21",
    "environments": {
        "PROD": {
            "bcinstance" : "BC21",
            "runnergroup": "prod_customer",
        },
        "TEST": {
            "bcinstance" : "BC21TEST",
            "runnergroup": "test_customer",
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
