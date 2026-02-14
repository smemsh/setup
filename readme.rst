Setup
==============================================================================

Kubernetes lab cluster demo, provisioned by Terraform, running on Incus
(LXD) servers.  Kube node images baked by Ansible.  Flux brings the
workload online via GitOps.

Control plane bootstrap, through workload instantiation, are all defined
in the setup repository, so the cluster can be repeatedly re-initialized
from a checkout.  This facilitates development of the platform itself.

| Scott Mcdermott <scott@smemsh.net>
| https://github.com/smemsh/setup/
| https://spdx.org/licenses/GPL-2.0


Status
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Up to 64 worker nodes have been tested, but a handful is more typical.
The point is to implement a control plane and multiple workers in a full
Kubernetes stack, on real Terraformed infrastructure, yet hosted by one
or a small number of machines.  Instead of using more limited test
environments like Minikube, Kind, etc.

Notes:

- only used for author's demonstration purposes
- only one master control node implemented (for each plex)
- some functionality unpushed or encrypted (no external users)
- must pre-bake all os-base/virt-type/host-type combinations
- only one bake in progress at a time per plex

Primary development plex is called ``omniplex`` and the staging one is
called ``verniplex``.  In the future these may be joined together with
Cilium's ClusterMesh feature.


Overview
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ansible is used to bake and upload Kubernetes node base images in
`lxdbake.yml`_ (via `bin/lxdbake`_), using transient Terraformed
instances (created when ``baketime`` variable is set).

Bake and deploy roles and tasks for each node type are specified in
`types/`_ and `roles/`_.  Cluster configuration is described in
`terraform.tfvars`_ and ansible `vars/`_ files.  The ``plexhocs``
variable is a nested map that defines the global shape of all clusters
(ie each "plex").

Terraform provisions the defined Incus node instances for each plex, in
the right order.  Upon node deployment, `kubestrap.yml`_ brings up the
Kubernetes control plane, or joins a worker to the candidate pool.  Work
capacity then triggers Flux install via `fluxstrap.yml`_, which
implements the data plane.  Kubernetes objects are typically defined in
``HelmRelease`` values in `apps/`_, and a Kustomize build specified in
`clusters/`_ includes these for each plex.

The first node in a plex's node range (e.g. ``testplex1``) must always
be defined in ``plexhocs`` if any kube nodes are defined, and will be
provisioned as the control-plane master.  Multiple/arbitrary masters
are planned, but don't work yet.

Clusters are recreated by dependency cascade from the master, i.e.
``tfapply -replace=<masternode>`` re-creates the whole cluster.


Infrastructure
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Kubernetes nodes are privileged Incus system containers, fully
functional nodes running stock ``kube-apiserver`` or ``kubelet``
processes.  Despite the virtualized kernels, everything works, including
BPF networking with Cilium.  Nodes are ``incus_instance`` resources
created with some LXC config magic.

Upstream OCI images are read-through cached by a standalone Zot
container installed via Docker OCI registry, also an ``incus_instance``.
This registry can also be used to store CI pipeline build outputs.

Cluster host data is static and precomputed, so all hostfiles,
networking config and hostkeys for the "plex" are either baked into the
node images or given during node instantiation by cloud-init.  Adding
another "plex" amounts to adding another block of precomputed hostnames
and keys.

Bootstrap is directed by a user on an Ansible controller that has a
checked out repository with unlocked secrets.


Contents
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

directories:

=========================== ==============================================================
`terraform/`_               HCL defining cluster infrastructure on Incus nodes
`roles/`_                   ansible roles to apply onto nodes, image bake/config
`types/`_                   which roles/actions to apply onto different node types
`clusters/`_                flux kustomizations defining each cluster workload
`apps/`_                    kubernetes application manifests, etc
=========================== ==============================================================

plays:

=========================== ==============================================================
`lxdbake.yml`_              builds node images by node type and os base
`kubestrap.yml`_            kubernetes control plane bootstrap
`fluxstrap.yml`_            kubernetes data plane bootstrap
`kubedel.yml`_              drain and remove node from kubernetes cluster
=========================== ==============================================================

scripts:

=========================== ==============================================================
`bin/ansrole`_              applies ansible roles onto nodes, with several options
`bin/tfapply`_              wraps terraform apply with more concise output/summary
`bin/tfcloudinit`_          interact with ansible to get cloudinits at baketime
`bin/tfhosts`_              imports nsswitch hosts into terraform as data source
`bin/tfdeps`_               list dependencies of terraform objects
`bin/lxdbake`_              bake kube/standalone images of given node type for incus
`bin/mkgenders`_            genders format from ansible inventory conversion script
`bin/genders`_              genders format to ansible inventory conversion script
`callbacks/unixz.py`_       more concise fork of ansible unixy filter
`filters/ghreltags.py`_     ansible filter to get latest release tag from github
=========================== ==============================================================



Howto
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

TBD -- Submit an issue_ if interested.

..

.. _`issue`:                https://github.com/smemsh/setup/issues/

.. _`terraform/`:           https://github.com/smemsh/setup/tree/master/terraform/
.. _`roles/`:               https://github.com/smemsh/setup/tree/master/roles/
.. _`types/`:               https://github.com/smemsh/setup/tree/master/types/

.. _`lxdbake.yml`:          https://github.com/smemsh/setup/blob/master/lxdbake.yml
.. _`kubestrap.yml`:        https://github.com/smemsh/setup/blob/master/kubestrap.yml
.. _`fluxstrap.yml`:        https://github.com/smemsh/setup/blob/master/fluxstrap.yml
.. _`kubedel.yml`:          https://github.com/smemsh/setup/blob/master/kubedel.yml

.. _`bin/ansrole`:          https://github.com/smemsh/setup/blob/master/bin/ansrole
.. _`bin/tfapply`:          https://github.com/smemsh/setup/blob/master/bin/tfapply
.. _`bin/tfcloudinit`:      https://github.com/smemsh/setup/blob/master/bin/tfcloudinit
.. _`bin/tfhosts`:          https://github.com/smemsh/setup/blob/master/bin/tfhosts
.. _`bin/tfdeps`:           https://github.com/smemsh/setup/blob/master/bin/tfdeps
.. _`bin/lxdbake`:          https://github.com/smemsh/setup/blob/master/bin/lxdbake
.. _`bin/mkgenders`:        https://github.com/smemsh/setup/blob/master/bin/mkgenders
.. _`bin/genders`:          https://github.com/smemsh/setup/blob/master/bin/genders
.. _`callbacks/unixz.py`:   https://github.com/smemsh/setup/blob/master/callbacks/unixz.py
.. _`filters/ghreltags.py`: https://github.com/smemsh/setup/blob/master/filters/ghreltags.py

.. _`terraform.tfvars`:     https://github.com/smemsh/setup/blob/master/terraform/terraform.tfvars
.. _`vars/`:                https://github.com/smemsh/setup/tree/master/vars/
.. _`apps/`:                https://github.com/smemsh/setup/tree/master/apps/
.. _`clusters/`:            https://github.com/smemsh/setup/tree/master/clusters/
