# Windows signing using the existing OpenHD SignPath project

The ordinary ImageWriter build calls `.github/workflows/windows.yml` with signing
disabled. Pull requests and forks do not receive signing credentials. Signed
builds are requested manually from `OpenHD/OpenHD` using
`.github/workflows/imagewriter-signing.yml`. That caller is prepared in the OpenHD
repository, and uses the existing project rather than a second signing project.

The caller supplies an explicit, full ImageWriter commit SHA. All compilation,
artifact uploads, and signing requests run on a GitHub-hosted Windows runner.
The workflow signs ImageWriter, the locally built FAT32 formatter, and the NSIS
uninstaller first, verifies their timestamped signatures, packages them, then
signs and verifies the outer installer. Third-party Qt/OpenSSL/UUU binaries are
redistributed as supplied; this workflow does not sign them as OpenHD binaries.

## Activate the prepared integration

1. Confirm that the existing SignPath project's approved source coverage includes
   `https://github.com/OpenHD/OpenHD-ImageWriter` when built through the OpenHD
   caller workflow. The GitHub connector still validates the source/build origin;
   reusing the OpenHD project does not itself extend approval to ImageWriter.
   Link the GitHub trusted build system and grant the SignPath GitHub App access
   to both repositories as required by the project configuration.
2. Add these artifact configurations to the existing project, using the exact
   slugs referenced by the workflow:
   - `imagewriter-application`: [application XML](signpath/imagewriter-application.xml)
   - `imagewriter-installer`: [installer XML](signpath/imagewriter-installer.xml)
   Both expect the ZIP artifacts produced by `actions/upload-artifact@v4`.
3. Ensure the intended signing policy is valid, permits both artifact
   configurations, and grants the API-token user submitter rights. For Windows
   trust verification, use a policy with a publicly trusted certificate and
   timestamping. A private test certificate will fail the final trust checks
   unless the runner explicitly trusts it.
4. In **OpenHD/OpenHD**, set repository or organization variables
   `SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`, and
   `SIGNPATH_SIGNING_POLICY_SLUG` to the existing project's values. Add secret
   `SIGNPATH_API_TOKEN` with the permitted submitter token. Do not put the token
   in a variable, source file, or workflow input.
5. Publish the ImageWriter workflow and NSIS changes. Pin the OpenHD caller's
   `uses: .../windows.yml@dev-branch` reference to the reviewed ImageWriter commit
   SHA before activating signing. Publish the OpenHD caller and run **Sign
   Windows ImageWriter**, passing an ImageWriter commit containing these changes.

Missing configuration, rejected signing requests, invalid signatures, or missing
timestamps fail the signed build. It never falls back to publishing an unsigned
artifact as signed. Download `OpenHDImageWriter-Build-Full-Signed` from the
**OpenHD** workflow run. Normal builds publish
`OpenHDImageWriter-Build-Full-Unsigned` from ImageWriter.
The same run also publishes `OpenHDImageWriter-Windows-Portable-Signed`, which
includes the signed application executable and its runtime dependencies.

The former optional PFX certificate/password workflow is replaced by SignPath;
no private signing certificate is exported onto the runner. Signed builds are
manual so ordinary development pushes do not create approval requests.

See the [SignPath GitHub integration](https://docs.signpath.io/trusted-build-systems/github)
and [artifact configuration syntax](https://docs.signpath.io/artifact-configuration/syntax).
