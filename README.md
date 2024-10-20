# Fedora CoreOS Config
Base manifest configuration for
[Fedora CoreOS](https://coreos.fedoraproject.org/).

Use https://github.com/coreos/coreos-assembler to build it.

Discussions in
https://discussion.fedoraproject.org/c/server/coreos. Bug
tracking and feature requests at
https://github.com/coreos/fedora-coreos-tracker.

## About this repo

There is one branch for each stream. The default branch is
[`testing-devel`](https://github.com/coreos/fedora-coreos-config/commits/testing-devel),
on which all development happens. See
[the design](https://github.com/coreos/fedora-coreos-tracker/blob/master/Design.md#release-streams)
and [tooling](https://github.com/coreos/fedora-coreos-tracker/blob/master/stream-tooling.md)
docs for more information about streams.

All file changes in `testing-devel` are propagated to other
branches (to `bodhi-updates` through
[config-bot](https://github.com/coreos/fedora-coreos-releng-automation/tree/master/config-bot),
and to `testing` through usual promotion), with the
following exceptions:
- `manifest.yaml`: contains the stream "identity", such as
  the ref, additional commit metadata, and yum input repos.
- lockfiles (`manifest-lock.*` files): lockfiles are
  imported from `bodhi-updates` to `testing-devel`.
  Overrides (`manifest-lock.overrides.*`) are manually
  curated.

## Layout

We intend for Fedora CoreOS to be used directly for a wide variety
of use cases.  However, we also want to support "custom" derivatives
such as Fedora Silverblue, etc.  Hence the configuration in this
repository is split up into reusable "layers" and components on
the rpm-ostree side.

To derive from this repository, the recommendation is to add it
as a git submodule.  Then create your own `manifest.yaml` which does
`include: fedora-coreos-config/ignition-and-ostree.yaml` for example.
You will also want to create an `overlay.d` and symlink in components
in this repository's `overlay.d`.

## Overriding packages

By default, all packages for FCOS come from the stable
Fedora repos. However, it is sometimes necessary to either
hold back some packages, or pull in fixes ahead of Bodhi. To
add such overrides, one needs to add the packages to
`manifest-lock.overrides.$basearch.yaml`. E.g.:

```yaml
packages:
  # document reason here and link to any Bodhi update
  foobar:
    evra: 1.2.3-1.fc31.x86_64
```

Whenever possible, in the case of pulling in a newer
package, it is important that the package be submitted as an
update to Bodhi so that we don't have to carry the override
forever.

Once an override PR is merged,
[`coreos-koji-tagger`](https://github.com/coreos/fedora-coreos-releng-automation/tree/master/coreos-koji-tagger)
will automatically tag overridden packages into the pool.

## Adding packages to the OS

Since `testing-devel` is directly promoted to `testing`, it
must always be in a known state. The way we enforce this is
by requiring all packages to have a corresponding entry in
the lockfile.

Therefore, to add new packages to the OS, one must also add
the corresponding entries in the lockfiles:
- for packages which should follow Bodhi updates, place them
  in `manifest-lock.$basearch.json`
- for packages which should remain pinned, place them
  in `manifest-lock.overrides.$basearch.yaml`

There will be better tooling to come to enable this, though
one easy way to do this is for now:
- add packages to the correct YAML manifest
- run `cosa fetch --update-lockfile`
- commit only the new package entries

## Moving to a new major version (N) of Fedora

Updating this repo:

1. bump `releasever` in `manifest.yaml`
2. update the repos in `manifest.yaml` if needed
3. run `cosa fetch --update-lockfile`
4. PR the result

Update server changes:

1. Set a new update barrier for N-2 on all streams.
   In the barrier entry set a link to [the docs](https://docs.fedoraproject.org/en-US/fedora-coreos/update-barrier-signing-keys/).
   See [discussion](https://github.com/coreos/fedora-coreos-tracker/issues/480#issuecomment-631724629).

CoreOS Installer changes:

1. Update CoreOS Installer to know about the signing key used for the
   future new major version of Fedora (N+1). Note that the signing
   keys for N+1 won't get created until releng branches and rawhide
   becomes N+1.

Release engineering changes:

1. Verify that a few tags have been created. These should have been created
   by releng scripts on branching: 

- `f${releasever}-coreos-signing-pending`
- `f${releasever}-coreos-continuous`

2. The tag info for the coreos-pool tag has the new release (N) and
   next release (N+1) signing keys (just to stay ahead of the curve)
   and removes the old release (N-2) signing key. The following commands
   view the current settings and then update the list to 32/33/34 keys.
   You'll most likely have to get someone from releng to run the second
   command (`edit-tag`).

- `koji taginfo coreos-pool`
- `koji edit-tag coreos-pool -x tag2distrepo.keys="12c944d0 9570ff31 45719a39"`


3. `koji untag` N-2 packages from the pool (at some point we'll have GC
   in place to do this for us, but for now we must remember to do this
   manually or otherwise distRepo will fail once the signed packages are
   GC'ed). For example the following snippet finds all RPMs signed by the
   Fedora 31 key and untags them.

```
f31key=3c3359c4
key=$f31key
untaglist=''
for build in $(koji list-tagged --quiet coreos-pool | cut -f1 -d' '); do
    if koji buildinfo $build | grep $key 1>/dev/null; then
        untaglist+="${build} "
        echo "Adding $build to untag list"
    fi
done

# After verifying the list looks good:
#   - koji untag-build coreos-pool $untaglist
```

## CoreOS CI

Pull requests submitted to this repo are tested by
[CoreOS CI](https://github.com/coreos/coreos-ci). You can see the pipeline
executed in `.cci.jenkinsfile`. For more information, including interacting with
CI, see the [CoreOS CI documentation](https://github.com/coreos/coreos-ci/blob/master/README-upstream-ci.md).
