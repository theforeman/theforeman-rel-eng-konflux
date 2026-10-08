# Hermetic RPM builds for Foreman OCI images

This guide covers RPM dependency locking and hermetic Konflux builds for the Foreman,
Pulp, and Candlepin OCI images. It is for maintainers changing RPM package sets,
repository definitions, or the Konflux build configuration.

## Branch and image matrix

| Repository | `master` / nightly | `foreman-5.0` |
| --- | --- | --- |
| [foreman-oci-images](https://github.com/theforeman/foreman-oci-images) | Non-hermetic DNF resolution during the build. | Hermetic Konflux builds for Foreman and Foreman Proxy. Each image has its own RPM input and lockfile. |
| [pulp-oci-images](https://github.com/theforeman/pulp-oci-images) | Non-hermetic DNF resolution during the build. | Hermetic Konflux build for Pulp, with an RPM input and lockfile. |
| [candlepin-oci-images](https://github.com/theforeman/candlepin-oci-images) | Non-hermetic DNF resolution during the build. | Hermetic Konflux build for Candlepin, with an RPM input and lockfile. |

On `foreman-5.0`, each image's pull-request and push pipeline enables hermetic mode,
passes `USE_HERMETO_REPOS=true`, and identifies the RPM prefetch input in `.tekton/`.
The input describes the package set and repository files; the lockfile records the
resolved RPM transaction. The `master` nightly pipelines continue to resolve packages
with DNF during the build and do not use these RPM lockfiles.

A local `make build` invokes Podman directly. It is useful for checking the ordinary
Containerfile build path, but it does not exercise Konflux prefetching or validate a
hermetic build.

## RPM input and lockfile roles

Each hermetic image has an `rpms.in.yaml` and a generated `rpms.lock.yaml` beside its
Containerfile. The input declares the RPM names and `contentOrigin.repofiles`; the
repository files live under each repository's `repos/` directory. The lockfile pins the
selected RPM versions and checksums for prefetching.

Foreman and Foreman Proxy have separate input and lock pairs. Pulp and Candlepin each
have one pair. Keep package-set and repository changes in the corresponding image input
and repository files, then refresh and review its lockfile in the same change.

These inputs explicitly define `packages`. In `rpm-lockfile-prototype`, an explicit
package list takes precedence over package scanning in the Containerfile. Therefore,
changing a DNF install list in a Containerfile also requires updating that image's
`rpms.in.yaml`.

RPM signing keys remain part of the image's Containerfile setup: the key is copied or
provided by the base image and imported before the DNF transaction. The Hermeto prefetch
configuration consumes the repository files and lockfile; it does not need a separate
GPG key payload.

## Refresh a lockfile

Each repository also carries `make refresh-rpm-lockfiles` on `master` so future
versioned branches inherit the helper. Current `master` branches do not contain RPM
lock inputs, so the target checks for those files and exits with an explanation there.
Run it on the current `foreman-5.0` branch or another branch that contains the relevant
`rpms.in.yaml`; the Foreman target refreshes both Foreman and Foreman Proxy locks.

```bash
git switch foreman-5.0
make refresh-rpm-lockfiles
git diff --check
git diff -- images/*/rpms.lock.yaml
```

The target builds the official `rpm-lockfile-prototype` container locally with Podman
when the pinned helper image is not already present. It mounts the checkout with `:z` for
SELinux relabeling, runs from each image directory so relative `.repo` paths resolve, and
writes the generated lockfile in place. The default helper version is `v0.30.1`; change
`RPM_LOCKFILE_VERSION` only when intentionally testing or adopting another upstream
release. The helper image is local and is not published. Lock refresh is independent of
`make build`, GitHub Actions, and image publishing.

Review the complete lockfile diff. Confirm that requested packages remain represented,
that all expected repositories are present, and that checksums and versions changed only
as intended. Include changes to `rpms.in.yaml`, `.repo` files, and generated lockfiles
together.

## Konflux build and troubleshooting

The pull-request and push pipelines share the same hermetic RPM inputs. If a build fails:

1. Check the `prefetch-dependencies` task logs for repository, package, or lockfile
   resolution errors.
2. Check the `build-container` task logs for errors installing the prefetched RPMs.
3. Verify that the relevant branch-specific `.tekton/` file uses the correct image path,
   `prefetch-input`, `hermetic: "true"`, and `USE_HERMETO_REPOS=true` build argument.
4. Compare the image's Containerfile install list, `rpms.in.yaml`, and `.repo` inputs.

Use the Konflux PipelineRun and task logs as the build record. A successful local
`make build` does not replace a Konflux hermetic build.

After a change is merged, Konflux's branch push pipeline builds and publishes the image.
Do not use local Makefile `push` targets as the release process.

## References

- [Konflux: prefetching package-manager dependencies](https://konflux-ci.dev/docs/building/prefetching-dependencies/)
- [Hermeto: RPM dependencies](https://hermetoproject.github.io/hermeto/rpm/)
- [rpm-lockfile-prototype: running in a container](https://github.com/konflux-ci/rpm-lockfile-prototype#running-in-a-container)
- [rpm-lockfile-prototype: package scanning and precedence](https://github.com/konflux-ci/rpm-lockfile-prototype#containerfile-package-scanning-and-packages-precedence)
- [MintMaker: RPM lockfiles](https://konflux-ci.dev/docs/mintmaker/rpm-lockfile/)
- [MintMaker support](https://konflux-ci.dev/docs/mintmaker/support/)
- [MintMaker user guide](https://konflux-ci.dev/docs/mintmaker/user/)
- [Renovate documentation](https://docs.renovatebot.com/)
- [Foreman OCI images README](https://github.com/theforeman/foreman-oci-images/blob/master/README.md)
- [Pulp OCI images README](https://github.com/theforeman/pulp-oci-images/blob/master/README.md)
- [Candlepin OCI images README](https://github.com/theforeman/candlepin-oci-images/blob/master/README.md)
