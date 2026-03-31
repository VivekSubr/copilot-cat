# Packaging

This directory contains packaging configurations for distributing Copilot Cat.

| Format | Directory | Platform | Tool |
|--------|-----------|----------|------|
| Windows Installer (MSI) | `wix/` | Windows | [WiX Toolset](https://wixtoolset.org/) |
| Chocolatey | `chocolatey/` | Windows | [choco](https://chocolatey.org/) |
| RPM | `rpm/` | Fedora/RHEL | rpmbuild |
| DEB | `deb/` | Debian/Ubuntu | dpkg-deb |
| MSIX (Store) | `./` (root of pkg/) | Windows | [MakeAppx](https://learn.microsoft.com/en-us/windows/msix/) |

## Prerequisites

All packaging assumes you have already built and deployed the exe:

```powershell
nmake build
nmake deploy
```

The deployable files are in `build/Debug/` (or `build/Release/` for release builds).

## Quick start per format

### Windows Installer (MSI)
```powershell
# Install WiX 4+
dotnet tool install --global wix
# Build MSI
wix build pkg/wix/copilot-cat.wxs -o copilot-cat.msi
```

### Chocolatey
```powershell
cd pkg/chocolatey
choco pack
# Test install
choco install copilot-cat -s . --force
```

### RPM
```bash
rpmbuild -bb pkg/rpm/copilot-cat.spec --define "_topdir $(pwd)/rpmbuild"
```

### DEB
```bash
dpkg-deb --build pkg/deb/copilot-cat
```

### MSIX (Microsoft Store)
```powershell
# Generate placeholder icons (requires Pillow, or falls back to raw PNGs)
pip install Pillow
python pkg/gen_icons.py

# Build MSIX from static build
pkg\make_msix.cmd build\Release

# Build and sign with test certificate for local sideloading
pkg\make_msix.cmd build\Release /sign
```

Before submitting to the Store, update `AppxManifest.xml` with your
publisher identity from Partner Center and replace the placeholder icons.
See comments in `AppxManifest.xml` for details.
