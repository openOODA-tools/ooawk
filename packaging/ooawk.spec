Name:           ooawk
Version:        0.2.0
Release:        1%{?dist}
Summary:        Data-driven pattern scanning and text processing language with exact arithmetic.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/ooawk
Source0:        ooawk-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
ooawk is a sovereign, capability-bounded RECORD PROCESSOR written
in pure openOODA, featuring zero ambient authority, oote color themes,
and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/ooawk
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/ooawk-uninstall

%files
/usr/bin/ooawk
/usr/bin/ooawk-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.2.0-1
- Sovereign record processor and pattern scanning engine
