# Windows ImageWriter signing with SignPath

SignPath Foundation's confirmed arrangement is a separate ImageWriter project
inside the existing OpenHD OSS organization, sharing its production certificate.
The project's source repository and GitHub Actions origin are
`https://github.com/OpenHD/OpenHD-ImageWriter`. An OpenHD repository caller is
not required.

Ordinary pushes, pull requests and fork builds call `windows.yml` with signing
disabled. Run **Sign Windows ImageWriter** (`sign-windows.yml`) manually in the
canonical ImageWriter repository, selecting the branch containing the reviewed
workflow and the `test` or `release` mode. The workflow builds its own exact
commit (`github.sha`), so the source matches the build's origin metadata.

## Configure the ImageWriter project

1. Wait for SignPath to add ImageWriter as a separate project, then link its
   GitHub trusted build system and enable SignPath GitHub App access to the
   ImageWriter repository as required by their configuration.
2. Add these artifact configurations to the **ImageWriter** project:
   - `imagewriter-application`: [application XML](signpath/imagewriter-application.xml)
   - `imagewriter-installer`: [installer XML](signpath/imagewriter-installer.xml)
   Both expect ZIP artifacts from `actions/upload-artifact@v4`. Configurations
   previously added to the OpenHD project do not configure the new project.
3. In **OpenHD/OpenHD-ImageWriter**, configure these repository variables with
   the exact values from the new project's settings:
   - `SIGNPATH_ORGANIZATION_ID` (the existing OpenHD OSS organization ID)
   - `SIGNPATH_PROJECT_SLUG` (the new ImageWriter project's slug)
   - `SIGNPATH_TEST_SIGNING_POLICY_SLUG` (its test policy)
   - `SIGNPATH_RELEASE_SIGNING_POLICY_SLUG` (its release policy)
   - `SIGNPATH_TEST_CERTIFICATE_BASE64` (the public test certificate exported
     as DER and base64 encoded; never include a private key or PFX)
4. Add repository secret `SIGNPATH_API_TOKEN` for the CI submitter permitted
   by the ImageWriter project's signing policies. Never put it in a variable,
   source file or workflow input.

## Test signing and production review

Run with `test` first. Only this ephemeral GitHub-hosted runner imports the
configured public self-signed test certificate into its current-user trust
stores. Each signed file must have a valid timestamped signature from exactly
that certificate. Test outputs are labelled `-Test-Signed`; they are for
onboarding verification and are not publicly trusted distribution packages.
Do not install this certificate on end-user computers.

Once integration and origin verification work, send SignPath the successful
workflow/signing request links for their technical review. Their onboarding
email states that they then order and import the production certificate.

Run with `release` only once its policy is valid. Release builds never import
the test certificate; they require normal Windows trust and timestamping.

## Signed artifacts

All compilation and signing run on GitHub-hosted Windows. The application,
locally built FAT32 formatter and generated NSIS uninstaller are signed first.
The installer embeds those files, then the outer installer is signed. Third-party
Qt/OpenSSL/UUU binaries are redistributed as supplied.

The run publishes `OpenHDImageWriter-Build-Full-Signed` and
`OpenHDImageWriter-Windows-Portable-Signed` for release mode. Test mode publishes
those names with `-Test-Signed` instead; ordinary builds use `-Unsigned`.
The portable archive includes the application and its runtime dependencies.
Missing settings, failed requests, invalid signatures or missing timestamps
fail the build without falling back to unsigned publication as signed.

See the [SignPath GitHub integration](https://docs.signpath.io/trusted-build-systems/github)
and [artifact configuration syntax](https://docs.signpath.io/artifact-configuration/syntax).
