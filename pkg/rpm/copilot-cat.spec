Name:           copilot-cat
Version:        1.0.0
Release:        1%{?dist}
Summary:        Desktop pet cat AI assistant for GitHub Copilot
License:        ISC
URL:            https://github.com/copilot-cat
Source0:        copilot-cat-%{version}.tar.gz

BuildRequires:  cmake >= 3.16
BuildRequires:  gcc-c++
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtwebsockets-devel
BuildRequires:  qt6-qtquickcontrols2-devel

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtwebsockets
Requires:       qt6-qtquickcontrols2

%description
A desktop pet cat that serves as a visual interface for GitHub Copilot via MCP.
Features animated cat sprite, speech bubbles, and AI chat powered by
Copilot (MCP), OpenRouter, or custom commands.

%prep
%autosetup

%build
%cmake
%cmake_build

%install
install -Dm755 %{_vpath_builddir}/copilot-cat %{buildroot}%{_bindir}/copilot-cat
install -Dm644 pkg/rpm/copilot-cat.desktop %{buildroot}%{_datadir}/applications/copilot-cat.desktop

# Install assets
mkdir -p %{buildroot}%{_datadir}/copilot-cat/assets
cp -r assets/*.svg %{buildroot}%{_datadir}/copilot-cat/assets/

%files
%license LICENSE
%doc README.md
%{_bindir}/copilot-cat
%{_datadir}/applications/copilot-cat.desktop
%{_datadir}/copilot-cat/

%changelog
* Sun Mar 29 2026 CopilotCat <copilot-cat@github.com> - 1.0.0-1
- Initial package
