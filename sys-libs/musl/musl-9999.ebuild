# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit eapi8-dosym flag-o-matic multilib multilib-minimal toolchain-funcs prefix

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="git://git.musl-libc.org/musl"
	inherit git-r3
else
	VERIFY_SIG_OPENPGP_KEY_PATH="${BROOT}"/usr/share/openpgp-keys/musl.asc
	inherit verify-sig

	SRC_URI="https://musl.libc.org/releases/${P}.tar.gz"
	SRC_URI+=" verify-sig? ( https://musl.libc.org/releases/${P}.tar.gz.asc )"
	KEYWORDS="-* ~amd64 ~arm ~arm64 ~mips ~ppc ~ppc64 ~riscv ~x86"

	BDEPEND="verify-sig? ( sec-keys/openpgp-keys-musl )"
fi
GETENT_COMMIT="93a08815f8598db442d8b766b463d0150ed8e2ab"
GETENT_FILE="musl-getent-${GETENT_COMMIT}.c"
SRC_URI+="
	https://dev.gentoo.org/~blueness/musl-misc/getconf.c
	https://gitlab.alpinelinux.org/alpine/aports/-/raw/${GETENT_COMMIT}/main/musl/getent.c -> ${GETENT_FILE}
	https://dev.gentoo.org/~blueness/musl-misc/iconv.c
"

export CBUILD=${CBUILD:-${CHOST}}
export CTARGET=${CTARGET:-${CHOST}}
if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY} == cross-* ]] ; then
		export CTARGET=${CATEGORY#cross-}
	fi
fi

DESCRIPTION="Light, fast and simple C library focused on standards-conformance and safety"
HOMEPAGE="https://musl.libc.org"
LICENSE="MIT LGPL-2 GPL-2"
SLOT="0"
IUSE="headers-only"

MULTILIB_WRAPPED_HEADERS=( /usr/include/bits/{alltypes.h,dirent.h,errno.h,fcntl.h,fenv.h,float.h,hwcap.h,io.h,ioctl.h,ioctl_fix.h,ipc.h,ipcstat.h,kd.h,limits.h,link.h,mman.h,msg.h,poll.h,posix.h,ptrace.h,reg.h,resource.h,sem.h,setjmp.h,shm.h,signal.h,socket.h,soundcard.h,stat.h,statfs.h,stdint.h,syscall.h,termios.h,user.h,vt.h} )

QA_SONAME="/usr/lib/libc.so"
QA_DT_NEEDED="/usr/lib/libc.so"

is_crosscompile() {
	[[ ${CHOST} != ${CTARGET} ]]
}

just_headers() {
	use headers-only && is_crosscompile
}

pkg_setup() {
	if [ ${CTARGET} == ${CHOST} ] ; then
		case ${CHOST} in
		*-musl*) ;;
		*) die "Use sys-devel/crossdev to build a musl toolchain" ;;
		esac
	fi

	# fix for #667126, copied from glibc ebuild
	# make sure host make.conf doesn't pollute us
	if is_crosscompile || tc-is-cross-compiler ; then
		CHOST=${CTARGET} strip-unsupported-flags
	fi
}

src_unpack() {
	if [[ ${PV} == 9999 ]] ; then
		git-r3_src_unpack
	elif use verify-sig ; then
		# We only verify the release; not the additional (fixed, safe) files
		# we download.
		# (Seem to get IPC error on verifying in cross?)
		! is_crosscompile && verify-sig_verify_detached "${DISTDIR}"/${P}.tar.gz{,.asc}
	fi

	default
}

src_prepare() {
	default

	mkdir "${WORKDIR}"/misc || die
	cp "${DISTDIR}"/getconf.c "${WORKDIR}"/misc/getconf.c || die
	cp "${DISTDIR}/${GETENT_FILE}" "${WORKDIR}"/misc/getent.c || die
	cp "${DISTDIR}"/iconv.c "${WORKDIR}"/misc/iconv.c || die
}

multilib_src_configure() {
	tc-getCC ${CTARGET}

	just_headers && export CC=true

	local sysroot
	is_crosscompile && sysroot=/usr/${CTARGET}
	${S}/configure \
		--target=${CTARGET} \
		--prefix=${EPREFIX}${sysroot}/usr \
		--libdir=${EPREFIX}${sysroot}/usr/$(get_libdir) \
		--syslibdir=${EPREFIX}${sysroot}/lib \
		--disable-gcc-wrapper || die
}

multilib_src_compile() {
	emake obj/include/bits/alltypes.h
	just_headers && return 0

	emake AR=$(tc-getAR) RANLIB=$(tc-getRANLIB)
	if [[ ${CATEGORY} != cross-* ]] && multilib_is_native_abi; then
		emake -C "${T}" getconf getent iconv \
			CC="$(tc-getCC)" \
			CFLAGS="${CFLAGS}" \
			CPPFLAGS="${CPPFLAGS}" \
			LDFLAGS="${LDFLAGS}" \
			VPATH="${WORKDIR}/misc"
	fi

	$(tc-getCC) ${CFLAGS} -c -o libssp_nonshared.o  "${FILESDIR}"/stack_chk_fail_local.c || die
	$(tc-getAR) -rcs libssp_nonshared.a libssp_nonshared.o || die
}

multilib_src_install() {
	local target="install"
	just_headers && target="install-headers"
	emake DESTDIR="${D}" ${target}
	just_headers && return 0

	local sysroot
	is_crosscompile && sysroot=/usr/${CTARGET}
	local ldso=$(basename "${ED}"${sysroot}/lib/ld-musl-*)
	cat > ${T}/${CTARGET}-ldd <<- EOF
	#!/bin/sh
	exec ${EPREFIX}${sysroot}/lib/${ldso} --list -- "\$@"
	EOF
	into ${sysroot}/usr
	dobin ${T}/${CTARGET}-ldd
	multilib_is_native_abi && dosym ${CTARGET}-ldd ${sysroot}/usr/bin/ldd

	if [[ ${CATEGORY} != cross-* ]] ; then
		# Fish out of config:
		#   ARCH = ...
		#   SUBARCH = ...
		# and print $(ARCH)$(SUBARCH).
		local arch=$(awk '{ k[$1] = $3 } END { printf("%s%s", k["ARCH"], k["SUBARCH"]); }' config.mak)

		# The musl build system seems to create a symlink:
		# ${D}/lib/ld-musl-${arch}.so.1 -> /usr/lib/libc.so.1 (absolute)
		# During cross or within prefix, there's no guarantee that the host is
		# using musl so that file may not exist. Use a relative symlink within
		# ${D} instead.
		rm -f "${ED}"/lib/ld-musl-${arch}.so.1 || die
		dosym8 -r /usr/lib/libc.so /lib/ld-musl-${arch}.so.1

		# If it's still a dead symlnk, OK, we really do need to abort.
		[[ -e "${ED}"/lib/ld-musl-${arch}.so.1 ]] || die

		cp "${FILESDIR}"/ldconfig.in-r3 "${T}"/ldconfig.in || die
		sed -e "s|@@ARCH@@|${arch}|" "${T}"/ldconfig.in > "${T}"/${CTARGET}-ldconfig || die
		eprefixify "${T}"/${CTARGET}-ldconfig
		into /
		dosbin "${T}"/${CTARGET}-ldconfig
		into /usr
		if multilib_is_native_abi; then
			dosym ${CTARGET}-ldconfig /sbin/ldconfig
			dobin "${T}"/getconf
			dobin "${T}"/getent
			dobin "${T}"/iconv
			echo 'LDPATH="include ld.so.conf.d/*.conf"' > "${T}"/00musl || die
			doenvd "${T}"/00musl
		fi
		dolib.a libssp_nonshared.a
	fi
}

pkg_postinst() {
	is_crosscompile && return 0

	[ -n "${ROOT}" ] && return 0

	ldconfig -NX || die
}
