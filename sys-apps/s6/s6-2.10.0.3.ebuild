# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="skarnet.org's small and secure supervision software suite"
HOMEPAGE="https://www.skarnet.org/software/s6/"
SRC_URI="https://www.skarnet.org/software/${PN}/${P}.tar.gz"

LICENSE="ISC"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~amd64 ~arm ~x86"
IUSE="+execline static static-libs"

REQUIRED_USE="static? ( static-libs )"

RDEPEND="execline? ( >=dev-lang/execline-2.8.0.1:=[static-libs?] )
	>=dev-libs/skalibs-2.10.0.3:=[static-libs?]
"
DEPEND="${RDEPEND}"

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
		--with-lib=/usr/$(get_libdir)/execline \
		--with-lib=/usr/$(get_libdir)/skalibs \
		--with-sysdeps=/usr/$(get_libdir)/skalibs \
		$(usex execline '' '--disable-execline' ) \
		--enable-shared \
		$(use_enable static allstatic) \
		$(use_enable static static-libc) \
		$(use_enable static-libs static)
}

src_compile() {
	emake AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)"
}
