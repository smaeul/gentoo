# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="Suite of small networking utilities for Unix systems"
HOMEPAGE="https://www.skarnet.org/software/s6-networking/"
SRC_URI="https://www.skarnet.org/software/${PN}/${P}.tar.gz"

LICENSE="ISC"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~amd64 ~x86"
IUSE="+execline libressl ssl static static-libs"

REQUIRED_USE="static? ( static-libs )"

RDEPEND="execline? ( >=dev-lang/execline-2.8.0.1:=[static-libs?] )
	>=dev-libs/skalibs-2.10.0.3:=[static-libs?]
	>=sys-apps/s6-2.10.0.3:=[execline?,static-libs?]
	!static? (
		ssl? (
			!libressl? ( >=dev-libs/libretls-3.2.5:= )
			libressl? ( >=dev-libs/libressl-3.2.5:= )
		)
		>=net-dns/s6-dns-2.3.5.1:=
	)
"
DEPEND="${RDEPEND}
	static? (
		ssl? (
			!libressl? ( >=dev-libs/libretls-3.2.5[static-libs] )
			libressl? ( >=dev-libs/libressl-3.2.5[static-libs] )
		)
		>=net-dns/s6-dns-2.3.5.1[static-libs]
	)
"

HTML_DOCS=( doc/. )

src_prepare() {
	default

	# Avoid QA warning for LDFLAGS addition
	sed -i -e 's/.*-Wl,--hash-style=both$/:/' \
		configure || die
}

src_configure() {
	econf \
		--bindir=/bin \
		--dynlibdir=/usr/$(get_libdir) \
		--libdir=/usr/$(get_libdir)/${PN} \
		--with-dynlib=/usr/$(get_libdir) \
		--with-lib=/usr/$(get_libdir)/s6 \
		--with-lib=/usr/$(get_libdir)/s6-dns \
		--with-lib=/usr/$(get_libdir)/skalibs \
		--with-sysdeps=/usr/$(get_libdir)/skalibs \
		--enable-shared \
		$(use_enable ssl ssl libressl) \
		$(use_enable static allstatic) \
		$(use_enable static static-libc) \
		$(use_enable static-libs static)
}

src_compile() {
	emake AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)"
}
