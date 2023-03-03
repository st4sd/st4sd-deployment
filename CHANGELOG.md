# 2.0.0-alpha7

### New enhancements

- Allow fetching measured properties in st4sd-registry-backend
- Show measured properties for runs in st4sd-registry-ui

### Security

- Fix CVE-2022-25881 in st4sd-registry-ui

# 2.0.0-alpha6

### New enhancements

- Improved search functionality in the Experiment Registry UI
- Improved error-reporting in st4sd-runtime-service

### Bugs and regressions
- Surrogates: st4sd-runtime-service uses intra-dependencies to reduce the set of parameters which require an explicit `relationship.graphParameteers` mapping
- Fix resolution of environment variables in Components which use a `DEFAULTS` instruction

# 2.0.0-alpha

### New enhancements

- Runtime support for surrogates. The runtime registry supports defining relationships between graphs, using the relationships to auto-generate surrogate parameterised virtual experiment packages, and decide between starting a parameterised package and one of its surrogates based on a runtime policy.
- Local instance of ST4SD registry for parameterised virtual experiment packages. The registry supports viewing the parameterised packages in the ST4SD instance as well as runs of the parameterised packages and their logs. You can access your registry UI at `https://${your_domain}/registry-ui/`.
- [Documentation](https://st4sd.github.com/overview/installation) to install the full arsenal of ST4SD microservices locally.
- Public images! We will store our public images in https://quay.io/organization/st4sd/

### API Change
- New API to upload relationships (`ExperimentRestAPI.api_relationship_push()`) - see our documentation for [runtime support for surrogates](https://st4sd.github.com/overview/using-graph-relationships) documentation for more.
- Updated the API to start an experiment so that users can also request to use a runtime policy. For more information see our documentation [running virtual experiments on OpenShift](https://st4sd.github.com/overview/running-workflows-on-openshift)) and configuring [runtime policies](https://st4sd.github.com/overview/using-runtime-policies).

### Bugs and regressions
- Miscellaneous optimisations in error reporting

# 1.6.0

### New enhancements
- Improved definition of virtual experiment entries in the registry. They are now self-contained. We refer to them with the term `parameterised virtual experiment packages`.
  - Documentation for creating parameterised virtual experiment packages [here](https://st4sd.github.com/overview/creating-a-parameterised-package/).
- [Global ST4SD registry](https://st4sd.github.com/overview/using-the-virtual-experiments-registry-ui) of parameterised virtual experiments. The packages in this registry are accessible by all ST4SD deployments.

### API Change
- Updated the payload to `ExperimentRestAPI.api_experiment_push()` to support the new functionality that the ST4SD registry provides. Please read [instructions](https://st4sd.github.com/overview/migrating/) for updating v1.5.3 virtual experiment entries to v1.6.0 parameterised virtual experiment packages entries.

### Bugs and regressions
- Miscellaneous optimisations in error reporting

# v1.5.3

### New enhancements

- Support for virtual experiment interface (measure one or more characteristics of one or more input systems).
- Support defining namespace wide arguments to virtual experiment instances (e.g. `--executionMode="production"`)
- Support executing specific commits of virtual experiment definitions hosted on Git
- Alpha: Support customising kubernetes tasks via `components.resourceManager.kubernetes.podSpec`

### Bugs and regressions
- Miscellaneous fixes in the K8s backend and the Helm chart


# v1.5.2

### New enhancements

Updated MongoDB backend to 5.0.9

# v1.5.1

### Bugs and regressions
- Miscellaneous fixes in the K8s backend.

# v1.5.0

This is the first release of the toolkit as the brand Simulation Toolkit for Scientific Discovery!

### New enhancements

- Replaced custom deployment framework with helm charts

### Bugs and regressions
- Miscellaneous fixes and improvements


# v1.4.0

### New enhancements

- Improved error handling and syntax error reports. The runtime will now even report what it thinks you meant to type!
- Improved RBAC for Kubernetes objects, received clearance by ETE to deploy on shared clusters.
- Improved reactive implementation leading to greater scalability.
  - Support at least 4000 components per experiment.
- Garbage collection for kubernetes objects: Use it by providing the additionalOption `--executionMode=production`
  - For more information, run `elaunch.py --help` 
- Security
   - Improved authentication / authorization for services
- Support burstable and best-effort classes on k8s. Burstable pods start with 1/10th of their resource requirements and may grow.
  - Please read the [Kubernetes documentation regarding the `Quality of Service` and how that affects pod eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#interactions-of-pod-priority-and-qos).
  - You can configure the QoS of your kubernetes components by setting `component.resourceManager.kubernetes.qos` to [`Burstable`, `BestEffort`, `Guaranteed`] (match is case-insensitive). 
  - Default value is `Guaranteed`.

### Bugs and regressions
- Miscellaneous fixes and improvements

### API Change

Updated the internal structure of the `experiment` python module. For example, `experiment.db.ExperimentRestAPI` is now `experiment.service.db.ExperimentRestAPI`.

All microservices now require authentication. Additionally, the microservices now reject OpenShift tokens if the associated account does not have permission to `Get` the `workflow-authentication` Service object inside the namespace that the workflow stack is deployed to.

# v1.3.0

### New enhancements
- New MongoDB documents in the CDB are easier to digest
  - All documents now contain a `uid` field. Component documents also contain a `producers` field that points to the  `uids` of their producers.
  - For more information see the [api-quickstart notebooks](https://github.com/st4sd/st4sd-examples/).

### Bugs and regressions
-  Miscellaneous fixes and improvements

### API Change

- Renamed nearly all `experiment.db.ExperimentRestAPI.api_instance_*` methods to `experiment.db.ExperimentRestAPI.api_rest_uid_*`. Exceptions:
    - `api_instance_create` is now `api_experiment_start`
    - `api_instance_create_lambda` is now `api_experiment_start_lambda`
- Changed most `experiment.db.ExperimentRestAPI.cdb_*` methods to feature a consistent interface.
   - In the deprecated API, arguments to the `cdb_*` methods were automatically converted to regular strings. Now, this only happens to parameters other than `query`. The `query` argument is treated as a MongoDB query. 
   - For example, to query for documents containing the `hello` key with a value that matches the regular expression `world[0-9]+` you may use the `$regex` operator of MongoDB inside `query` like so: `api.cdb_get_document(query={"hello": {"$regex": "world[0-9]+"}})`. 
   - Documentation for the `$regex` operator: <https://docs.mongodb.com/manual/reference/operator/query/regex>
     - You can find more information on MongoDB operators at the official documentation: <https://docs.mongodb.com/manual/reference/operator/query/>
- We introduce a new class `experiment.db.ExperimentRestAPIDeprecated` that offers the interface of the now deprecated API. Users may find this new class useful to update their Python notebooks with minimum effort to make them compatible with the latest stable version of the workflow stack. Users may then work on a copy of their code to gradually replace the use of `experiment.db.ExperimentRestAPIDeprecated` with `experiment.db.ExperimentRestAPI`.
- Components that define neither `workflowAttributes.maxRestarts` nor `workflowAttributes.restartHookFile` will no longer re-execute indefinitely on a `ResourceExhausted` exit-reason. They will restart up to 3 times.
