# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=5

USE_RUBY="ruby23 ruby24 ruby25 ruby26"

# Use rdoc recipe to avoid obsolete Rakefile
RUBY_FAKEGEM_RECIPE_DOC="rdoc"
RUBY_FAKEGEM_EXTRADOC="CONTRIBUTION_GUIDELINES.rdoc README.rdoc"

inherit ruby-fakegem

DESCRIPTION="Making tests easy on the fingers and eyes"
HOMEPAGE="http://thoughtbot.com/projects/shoulda"
SRC_URI="https://github.com/thoughtbot/${PN}/tarball/v${PV} -> ${P}.tar.gz"
RUBY_S="thoughtbot-${PN}-*"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~arm ~arm64 ~hppa ppc ppc64 sparc x86 ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x64-solaris ~x86-solaris"
IUSE=""

# tests seem to be quite broken :( They require working version of
# various rails versions. There appear to be unit and matcher tests but
# they can't be run on their own.
RESTRICT=test
