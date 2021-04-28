# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="Set of tiny linux utilities"
HOMEPAGE="https://www.skarnet.org/software/s6-linux-utils/"
SRC_URI="https://www.skarnet.org/software/${PN}/${P}.tar.gz"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64 ~arm ~x86"
IUSE="static"

RDEPEND="!static? ( >=dev-libs/skalibs-2.10.0.3:= )"
DEPEND="${RDEPEND}
	static? ( >=dev-libs/skalibs-2.10.0.3[static-libs] )
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
		--with-lib=/usr/$(get_libdir)/skalibs \
		--with-sysdeps=/usr/$(get_libdir)/skalibs \
		$(use_enable static allstatic) \
		$(use_enable static static-libc)
}

src_compile() {
	emake AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)"
}
