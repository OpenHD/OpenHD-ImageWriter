# Publishing OpenHD ImageWriter on the AUR

The package base is `openhdimagewriter-git`. The recipe builds current
`dev-branch` sources and runs the backend and catalog tests. A Git package
uses the `-git` suffix as required by the
[VCS package guidelines](https://wiki.archlinux.org/title/VCS_package_guidelines).
The AUR stores build recipes; publication does not place the program in Arch's
official binary repositories.

## Validate before submission

Merge the packaging changes into upstream `dev-branch` so that the public
source URL includes them. On an up-to-date Arch Linux system, copy `PKGBUILD`
and `.SRCINFO` into a separate working directory and run as a regular user:

```sh
sudo pacman -S --needed base-devel git devtools namcap
makepkg --printsrcinfo > .SRCINFO
extra-x86_64-build
namcap PKGBUILD ./*.pkg.tar.zst
```

Review all namcap findings. Install and launch the package, check the image
catalog and file picker, and confirm disk enumeration and desktop
authorization. CI builds x86_64; validate aarch64 separately on Arch Linux ARM
before claiming that architecture is tested. Do not test flashing against a
disk containing important data.

The unified CI workflow also verifies committed metadata, builds the exact
checked-out revision, runs tests, and checks installed desktop files. Its
`aur-submission.tar.gz` contains the public recipe and metadata. The binary
package is a separate artifact and must not be committed to the AUR.

## Initial publication

Create or use the OpenHD maintainer's account at
[aur.archlinux.org](https://aur.archlinux.org/), register its SSH public key,
and verify the SSH host key using Arch's published information. Check whether
`openhdimagewriter-git` or an equivalent package already exists; coordinate
with its maintainer instead of overwriting an existing package.

Follow the [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines).
From the upstream working tree, run:

```sh
upstream_dir="$PWD"
git -c init.defaultBranch=master clone \
  ssh://aur@aur.archlinux.org/openhdimagewriter-git.git ../openhdimagewriter-aur
cd ../openhdimagewriter-aur
cp "$upstream_dir/PKGBUILD" "$upstream_dir/.SRCINFO" .
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "Add OpenHD ImageWriter Git package"
git push origin master
```

Only the recipe and metadata belong in this repository. After successful
publication, verify the package page and update the main README with its
confirmed URL and an AUR helper installation command.

## Maintenance

When dependencies or the recipe change, update `pkgver` to the current source
revision, or increment `pkgrel` if the version is unchanged. Regenerate
`.SRCINFO` with `makepkg --printsrcinfo`, validate the package, and commit and
push both files to the AUR repository. Keep upstream `.SRCINFO` in sync too.
Ordinary upstream Git commits do not require publishing a new recipe.

A stable `openhdimagewriter` package should use an actual published release
archive and its SHA-256 checksum. Do not label the current development source
as a stable 4.0.0 release solely because that version appears in CMake.
