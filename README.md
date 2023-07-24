# Docusaurus-aca-yaml (Docusaurus in Azure Container App using yaml deployment)

This repository includes a simple Docusaurus Site with a basic template for hosting product documentation. The repository is a helper for exploring different `DevOps` options for Container Apps cse-devblog

This flow takes advantage of the `YAML` option during a containerapp create/update/revision copy [link](https://aka.ms/azure-container-apps-yaml)

## Bootstrap Infrastructure

Validate you are connected to an Azure subscription and update `infra/sample.main.parameters.json` to `infra/main.parameters.json` with your details.

```bash
make bootstrap
```

or

```bash
az deployment sub create --name docusaurus-aca-yaml --template-file infra/main.bicep --parameters infra/main.parameters.json --location australiaeast
```

For this flow, the infrastructure bootstrapped looks like this:

![architecture](readme_diagram.png)

## Deploy application

For the demo, we will be orchestrating the deployment locally. In other words, we will be running the pipeline commands locally.

before jumping into the steps. Here is the template we used for rendering:

```yaml
location: australiaeast # can be updated based on the bootstrap -> in our case needed be hardcoded for client
name: $APPNAME
resourceGroup: $RG
type: Microsoft.App/containerApps
identity:
  type: userAssigned
  userAssignedIdentities: {
      '$MANAGED_IDENTITY_ID' # the identity that has pullrole from the ACR
    }
properties:
  managedEnvironmentId: $MANAGED_ENVIRONMENT_ID # environment from the bootstrap
  configuration:
    activeRevisionsMode: Single # we didn't need multiple, but in this workflow is achivable
    identity:
      userAssignedIdentities: $MANAGED_IDENTITY_ID # the identity that has pullrole from the ACR and to use in the registry property
    ingress:
      external: true
      allowInsecure: false
      targetPort: 3000
      transport: Auto
    registries:
      - identity: $MANAGED_IDENTITY_ID # the identity that has pullrole from the ACR
        server: $REGISTRYNAME.azurecr.io
  template:
    containers:
      - name: docusaurus
        image: $REGISTRYNAME.azurecr.io/docusaurus:$DOCS_VERSION
```

Now, the steps:

1. Build the container

    After running the bootstrap, in this step we will be creating the docker container and pushing it into the bootstrapped ACR.

    ```bash
    make ci-package
    ```

    or

    ```bash
    # package
    DOCS_VERSION=${RELEASE:-local}
    export ACR=$(az deployment sub show -n docusaurus-aca-yaml --query 'properties.outputs.containerRegistryServer.value' -o tsv)

    docker build \
        -t docusaurus:$DOCS_VERSION \
        -f ./ci/Dockerfile \
        ./src/docusaurus

    # tag
    docker tag docusaurus:$DOCS_VERSION $ACR/docusaurus:$DOCS_VERSION
    docker tag docusaurus:$DOCS_VERSION $ACR/docusaurus:latest

    # push
    az acr login -n $ACR
    docker push $ACR/docusaurus:$DOCS_VERSION
    docker push $ACR/docusaurus:latest
    ```

2. Update the deployment yaml

    In this step we will be generating a deployment config. As you can see, dev team will require to have knowledge about the infra and requirements for the containerapp. This is one of the `cons` of this flow.

    ```bash
    make prepare-template
    ```

    or

    ```bash
    source ./ci/prepare_template.sh
    ```

    After rendering the template, the user can find the yaml that will be used for deployment under `ci/deployment.yaml`.

3. use `az cli + deployment.yaml` to deploy/create the containerapp

    ```make
    make deploy
    ```

    or

    ```bash
    export RG=$(az deployment sub show -n docusaurus-aca-yaml --query 'properties.outputs.resourceGroupName.value' -o tsv)
    az containerapp create -n "docusaurus" -g $RG --yaml ci/deployment.yaml
    ```

## Continuous deployment

In this flow, the continuous deployment depends on the team updating the version of the image and simply exporting the new version as `RELEASE` before rendering the template and finally deploying the app. In other words, the team only includes that step in their release pipeline. If the team prefers, the base template can be created with all the infrastructure details once, and just update the tag in for the container.

```bash
export RELEASE=v1.0.0
make ci-package
make prepare-template
make deploy
```

## Summary

In this workflow, there's a bit of a mix-up between what the operations team does and what the development team does. You could think of them as two separate teams, but then the dev team needs to really get the hang of the infrastructure they're working on. They could do this by asking the operations team for deployment values or by taking a closer look at the bootstrap release.

One cool thing about this setup is that it lets the dev team have a lot of control over how the app is deployed and set up. But, there's a bit of a snag. Figuring out the yaml schema can be like trying to solve a puzzle without the picture on the box. It's hard to understand the properties. In our journey, we looked to properties from the ARM template schema for guidance.

With this workflow, because the container app is created after a new version of the container is released, it always ends up in the 'Provisioned' and 'Running' state. That's a big win since it allows continuous monitoring.

### Pros

- Control: The dev team gets to call the shots on how the app is deployed and set up. That's a lot of power in their hands.
- Always Running: Because the container app is created after a new version is released, it always ends up `Provisioned` and `Running`. This keeps things going smoothly and allows for constant monitoring.
- Using Resources: The team uses properties from the ARM template schema to complete the `yaml` template.

### Cons

- Know-it-all: The dev team needs to know a lot about the infrastructure they're working on, which could be a bit of a learning curve.
- Puzzle Solver: The yaml schema is like a puzzle with missing pieces. It's tough to understand the properties, which can slow things down.
- Asking for Help: Depending on how much the dev team knows about the infrastructure, they might need to keep asking the operations team for deployment values. This could slow down the process.
