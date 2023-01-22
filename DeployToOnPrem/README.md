# DeployToOnPrem

GitHub Action to deploy Microsoft Dynamics 365 Business Central Extension App to On-Premises environment.

Prerequisites:

* self-hosted runner
* Business Central on-premises installation
* running instance of Business Central
* existing app artifact created with AL-GO CI/CD action (latest in selected branch)

The deployment will succeed, if the app is published for the first time or if the version number of the updated app is newer. If the app to be installed has the same version number as the one already installed, the action issues a message that there is nothing to do.

## Parameters

### token

The GitHub token running the action, not required, default = github.token

### bcVersion

Specifies the version of the BC System running i.e. 20, 21, 22, ..., required

### onPremInstance

Specifies the name of a Business Central Server instance, required

### useBranch

The branch to get the desired artifacts (.app files) to deploy, required

### syncMode

Specifies how the database schema for the tenant database is synchronized with the database schema that the target Business Central app's objects define, not required, default = Add

## Runners configuration and security

The configuration of the self-hosted runners must be made with caution for security reasons. The following basic precautions should be observed:

For Runners, which are set up and installed on productive systems, the following applies:

1. Each runner should be assigned to their own group (always only one runner per group)
2. Such groups should only have access to certain repos
3. In addition, access should be restricted to one workflow (for example: *orgname/reponame/.github/workflows/PublishToOnPremEnvironment.yaml@refs/heads/main*)

The repo that has access to the workflow should have an action variable with the name PUBLISH_TO_RUNNERGROUP with a content of the name of the runner group. So it is possible to run the publishing workflow job only if the variable is defined.
