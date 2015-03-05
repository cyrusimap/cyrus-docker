set shiftwidth=4
set tabstop=4
set expandtab

autocmd BufNewFile,BufRead /srv/cyrus-imapd.git/*/*.{c,h} set tabstop=8 softtabstop=4 shiftwidth=4 list listchars=tab:>. noexpandtab
autocmd BufNewFile,BufRead /srv/cyrus-imapd.git/cunit/cunit.pl set tabstop=8 softtabstop=4 shiftwidth=4 list listchars=tab:>. noexpandtab
autocmd BufNewFile,BufRead /srv/cyrus-imapd.git/configure.ac set tabstop=8 shiftwidth=8 noexpandtab

