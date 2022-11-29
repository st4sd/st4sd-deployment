# Simulation Toolkit for Scientific Discovery (ST4SD)


## Details

This repository contains the deployment files and instructions for installing the [Simulation Toolkit For Scientific Discovery (ST4SD)](https://github.com/st4sd/overview).

## Quick links

- [Getting started](#getting-started)
- [Development](#development)
- [Help and Support](#help-and-support)
- [Contributing](#contributing)
- [License](#license)

## Getting started

We currently support installing the ST4SD stack [via helm](docs/install-helm-chart.md).

### Requirements

1. **Access to an OpenShift cluster with `cluster-admin` permissions**
    - Required for creation of a kubernetes objects (such as CustomResourceDefinition and Role Based Access Control (RBAC)). Regular updates to the workflow stack do not require `cluster-admin` permissions, only permissions to modify objects in the namespace that holds the workflow stack.
2. **OpenShift command line tools  (`oc` v4.9+)**
    - Instructions: <https://docs.openshift.com/container-platform/4.9/cli_reference/openshift_cli/getting-started-cli.html>
    - Install stable version of`oc` from <https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/>
    - It is good practice to periodically update your `oc` command line utility to ensure that your `oc` binary contains the latest patches and bug-fixes.

## Development

Coming soon.

## Help and Support

Please feel free to reach out to one of the maintainers listed in the [MAINTAINERS.md](MAINTAINERS.md) page.

## Contributing

We always welcome external contributions. Please see our [guidance](CONTRIBUTING.md) for details on how to do so.

## License

This project is licensed under the Apache 2.0 license. Please [see details here](LICENSE.md).


## After installing the toolkit

1. Take a look at the [troubleshooting-deployment guide](docs/troubleshooting.md) to ensure that your workflow stack is properly instantiated.
1. [Get started with ST4SD.](https://st4sd.github.io/overview/)
1. Test your ST4SD deployment using the [st4sd-examples notebooks](https://github.com/st4sd/st4sd-examples).
1. Visit the ST4SD runtime service: at `${routePrefix}.{clusterRouteDomain}/rs`
    >**Note**: Replace `${key}` with the value of `key` in your `deployment-options.yaml` file (the one that you created when following the [requirements instructions](docs/install-requirements.md)).
1. Visit the ST4SD Registry website: at `${routePrefix}.{clusterRouteDomain}/registry-ui/`