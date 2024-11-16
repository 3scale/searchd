Name:           manticore-tzdata
Release:        1
Summary:        Direct Manticore into OS tzdata

Requires:       tzdata

BuildArch:      noarch

License:        MIT
Version:        1.1

%description
Symlinks OS tzdata of Red Hat Enterprise Linux 9 for Manticore use.

%install
mkdir -p %{buildroot}/usr/share/manticore
ln -s ../zoneinfo %{buildroot}/usr/share/manticore/tzdata

%files
/usr/share/manticore/tzdata
