#!/bin/bash
# MIT License
#
# Copyright (c) 2024 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

GIT_TOP_LEVEL=$(git rev-parse --show-toplevel)

# Inputs and Defaults
PACKAGE_NAME="${1:-ROCm-SDK-Examples}"
PACKAGE_VERSION="${2:-6.2.0}"
PACKAGE_INSTALL_PREFIX="${3:-/opt/rocm/examples}"
BUILD_DIR="${4:-$GIT_TOP_LEVEL/build}"
DEB_DIR="${5:-$BUILD_DIR/deb}"
RPM_DIR="${6:-$BUILD_DIR/rpm}"
DEB_PACKAGE_RELEASE="${7:-local.9999}"
RPM_PACKAGE_RELEASE="${8:-local.9999}"

STAGING_DIR="$BUILD_DIR"/"$PACKAGE_NAME"-"$PACKAGE_VERSION"

PACKAGE_CONTACT="ROCm Developer Support <rocm-dev.support@amd.com>"
PACKAGE_DESCRIPTION_SUMMARY="A collection of examples for the ROCm software stack"
PACKAGE_HOMEPAGE_URL="https://github.com/ROCm/ROCm-examples"

# Directories to be included in the package
SOURCE_DIRS=(
    "AI"
    "Applications"
    "Common"
    "Dockerfiles"
    "External"
    "HIP-Basic"
    "Libraries"
    "LLVM_ASAN"
)


print_input_variables() {
    echo "********** Input Variables **********"
    echo "PACKAGE_NAME=$PACKAGE_NAME"
    echo "PACKAGE_VERSION=$PACKAGE_VERSION"
    echo "PACKAGE_INSTALL_PREFIX=$PACKAGE_INSTALL_PREFIX"
    echo "BUILD_DIR=$BUILD_DIR"
    echo "DEB_DIR=$DEB_DIR"
    echo "RPM_DIR=$RPM_DIR"
    echo "DEB_PACKAGE_RELEASE=$DEB_PACKAGE_RELEASE"
    echo "RPM_PACKAGE_RELEASE=$RPM_PACKAGE_RELEASE"
    echo "************************************"
}


copy_sources() {
    mkdir -p "$STAGING_DIR"

    echo "** Copying sources to $STAGING_DIR **"

    # Copy source files in root to package
    cp LICENSE.md CMakeLists.txt README.md "$STAGING_DIR"

    # Copy source directories to package
    for dir in "${SOURCE_DIRS[@]}"; do
        rsync -a --exclude 'build' --exclude '.gitignore' \
            --exclude '*.vcxproj**' --exclude '*.sln' --exclude 'bin' \
            --exclude '*.o' --exclude '*.exe' "$dir" "$STAGING_DIR"
    done
}

create_deb_package() {
    local deb_root="$BUILD_DIR/deb_tmp"
    local deb_install_dir="$deb_root/$PACKAGE_INSTALL_PREFIX"
    local deb_control_file="$deb_root/DEBIAN/control"

    # Create directories for DEB package artifacts
    mkdir -p "$deb_root/DEBIAN" "$deb_install_dir"

    echo "** Creating DEB package in $DEB_DIR **"

    # Copy the sources to the install directory
    cp -r "$STAGING_DIR"/* "$deb_install_dir"/

    # Create control file
    cat <<EOF >"$deb_control_file"
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Architecture: amd64
Maintainer: $PACKAGE_CONTACT
Description: $PACKAGE_DESCRIPTION_SUMMARY
Homepage: $PACKAGE_HOMEPAGE_URL
Depends:
Section: devel
Priority: optional
EOF

    # Build DEB package
    fakeroot dpkg-deb --build "$deb_root" \
        "$DEB_DIR"/"$PACKAGE_NAME"_"$PACKAGE_VERSION"-"$DEB_PACKAGE_RELEASE"_amd64.deb

    # Clean up
    # rm -rf $deb_root
}

create_rpm_package() {
    local rpm_root="$BUILD_DIR"/rpm_tmp
    local rpm_build_dir="$rpm_root/BUILD"
    local rpm_rpms_dir="$rpm_root/RPMS"
    local rpm_source_dir="$rpm_root/SOURCES"
    local rpm_spec_dir="$rpm_root/SPECS"
    local rpm_srpm_dir="$rpm_root/SRPMS"

    local spec_file="$rpm_spec_dir/$PACKAGE_NAME.spec"

    # Create directories for all the RPM build artifacts
    mkdir -p "$rpm_build_dir" "$rpm_rpms_dir" "$rpm_source_dir" "$rpm_spec_dir" "$rpm_srpm_dir"

    echo "** Creating RPM package in $RPM_DIR **"

    # Create the spec file
    cat <<EOF > "$spec_file"
%define _build_id_links none
%global debug_package %{nil}
Name:           $PACKAGE_NAME
Version:        $PACKAGE_VERSION
Release:        $RPM_PACKAGE_RELEASE%{?dist}
Summary:        $PACKAGE_DESCRIPTION_SUMMARY
License:        MIT
URL:            $PACKAGE_HOMEPAGE_URL
Source0:        %{name}-%{version}.tar.gz
BuildArch:      %{_arch}

%description
$PACKAGE_DESCRIPTION_SUMMARY

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}$PACKAGE_INSTALL_PREFIX
cp -r * %{buildroot}$PACKAGE_INSTALL_PREFIX

%files
$PACKAGE_INSTALL_PREFIX

%changelog
EOF

    # Create source tarball
    tar czf "$rpm_source_dir/$PACKAGE_NAME-$PACKAGE_VERSION.tar.gz" \
        -C "$BUILD_DIR" "$PACKAGE_NAME"-"$PACKAGE_VERSION"

    # Build the RPM package
    rpmbuild --define "_topdir $rpm_root" -ba "$spec_file"

    # Move the generated RPM file to RPM_DIR
    find "$rpm_rpms_dir" -name "$PACKAGE_NAME-$PACKAGE_VERSION-*.rpm" -exec mv {} "$RPM_DIR" \;

    # Clean up
    # rm -rf $rpm_build_dir $rpm_source_dir $rpm_spec_dir $rpm_rpms_dir $rpm_srpm_dir
}

## Main Program ##

# Clean up previous build artifacts
rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR" "$DEB_DIR" "$RPM_DIR"

pushd "$GIT_TOP_LEVEL" || exit

# Print input variables
print_input_variables

# Copy sources to build directory
copy_sources

# Create DEB package
create_deb_package

# Create RPM package
create_rpm_package

popd || exit
