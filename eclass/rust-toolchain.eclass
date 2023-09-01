# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rust-toolchain.eclass
# @MAINTAINER:
# Rust Project <rust@gentoo.org>
# @SUPPORTED_EAPIS: 8
# @BLURB: helps map gentoo arches to rust ABIs
# @DESCRIPTION:
# This eclass contains helper functions, to aid in proper rust-ABI handling for
# various gentoo arches.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

# @ECLASS_VARIABLE: RUST_TOOLCHAIN_BASEURL
# @DESCRIPTION:
# This variable specifies the base URL used by the
# rust_arch_uri and rust_all_arch_uris functions when
# generating the URI output list.
: "${RUST_TOOLCHAIN_BASEURL:=https://portage.smaeul.xyz/distfiles/}"

# @FUNCTION: rust_abi
# @USAGE: [CHOST-value]
# @DESCRIPTION:
# Outputs the Rust ABI name from a CHOST value, uses CHOST in the
# environment if none is specified.

rust_abi() {
	local CTARGET=${1:-${CHOST}}
	case ${CTARGET%%*-} in
		*)            echo ${CTARGET};;
  esac
}

# @FUNCTION: rust_arch_uri
# @USAGE: <rust-ABI> <base-uri> [alt-distfile-basename]
# @DESCRIPTION:
# Output the URI for use in SRC_URI, combining $RUST_TOOLCHAIN_BASEURL
# and the URI suffix provided in ARG2 with the rust ABI in ARG1, and
# optionally renaming to the distfile basename specified in ARG3.
#
# @EXAMPLE:
# SRC_URI="amd64? (
#	 $(rust_arch_uri x86_64-gentoo-linux-musl rustc-${STAGE0_VERSION})
# )"
#
rust_arch_uri() {
	if [ -n "$3" ]; then
		echo "${RUST_TOOLCHAIN_BASEURL}${2}-${1}.tar.xz -> ${3}-${1}.tar.xz"
	else
		echo "${RUST_TOOLCHAIN_BASEURL}${2}-${1}.tar.xz"
	fi
}

# @FUNCTION: rust_all_arch_uris
# @USAGE: <base-uri> [alt-distfile-basename]
# @DESCRIPTION:
# Outputs the URIs for SRC_URI to help fetch dependencies, using a base URI
# provided as an argument. Optionally allows for distfile renaming via a specified
# basename.
#
# @EXAMPLE:
# SRC_URI="$(rust_all_arch_uris rustc-${STAGE0_VERSION})"
#
rust_all_arch_uris()
{
	echo "
	arm64? (
		elibc_musl?  ( $(rust_arch_uri aarch64-gentoo-linux-musl "$@") )
	)
	ppc64? (
		big-endian?  ( $(rust_arch_uri powerpc64-gentoo-linux-musl   "$@") )
		!big-endian? ( $(rust_arch_uri powerpc64le-gentoo-linux-musl "$@") )
	)
	"
}
