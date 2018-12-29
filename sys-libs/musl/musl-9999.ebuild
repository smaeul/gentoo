# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit flag-o-matic multilib multilib-minimal toolchain-funcs

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="git://git.musl-libc.org/musl"
	inherit git-r3
else
	SRC_URI="http://www.musl-libc.org/releases/${P}.tar.gz"
	KEYWORDS="-* ~amd64 ~arm ~arm64 ~mips ~ppc ~ppc64 ~x86"
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
HOMEPAGE="http://www.musl-libc.org/"
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
	if [[ ${PV} == 9999 ]]; then
		git-r3_src_unpack
	else
		unpack "${P}.tar.gz"
	fi
	mkdir misc || die
	cp "${DISTDIR}"/getconf.c misc/getconf.c || die
	cp "${DISTDIR}/${GETENT_FILE}" misc/getent.c || die
	cp "${DISTDIR}"/iconv.c misc/iconv.c || die
}

multilib_src_configure() {
	tc-getCC ${CTARGET}
	just_headers && export CC=true

	local sysroot
	is_crosscompile && sysroot="${EPREFIX}"/usr/${CTARGET}
	${S}/configure \
		--target=${CTARGET} \
		--prefix=${sysroot}/usr \
		--libdir=${sysroot}/usr/$(get_libdir) \
		--syslibdir=${sysroot}/lib \
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

	# musl provides ldd via a sym link to its ld.so
	# Fish out of config:
	#   ARCH = ...
	#   SUBARCH = ...
	# and print $(ARCH)$(SUBARCH).
	local arch=$(awk '{ k[$1] = $3 } END { printf("%s%s", k["ARCH"], k["SUBARCH"]); }' config.mak)
	local sysroot
	is_crosscompile && sysroot=/usr/${CTARGET}
	dosym ../../lib/ld-musl-${arch}.so.1 ${sysroot}/usr/bin/${CTARGET}-ldd
	multilib_is_native_abi && dosym ${CTARGET}-ldd ${sysroot}/usr/bin/ldd

	if [[ ${CATEGORY} != cross-* ]] ; then
		[[ -e "${D}"/lib/ld-musl-${arch}.so.1 ]] || die
		cp "${FILESDIR}"/ldconfig.in "${T}" || die
		sed -e "s|@@ARCH@@|${arch}|" "${T}"/ldconfig.in > "${T}"/${CTARGET}-ldconfig || die
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

	[ "${ROOT}" != "/" ] && return 0

	ldconfig -NX || die
}
