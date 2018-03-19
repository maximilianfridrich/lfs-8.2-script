#!/bin/bash

if [ ! -f ./shared_functions.sh ]
then
  echo "!! Fatal Error 1: './shared_functions.sh' not found."
  exit 1
fi
source ./shared_functions.sh

# -----------------------------------------------------------------------------
# Set up environment
# -----------------------------------------------------------------------------

init () {
echo "... Setting up of the Environment"
echo ".... Making of .bash_profile"
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

echo ".... Making of .bashrc"
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

echo "Now run source ~/.bash_profile"
exit 0
}


# -----------------------------------------------------------------------------
# Building the temporary toolchain
# Chapters 5.4 to 5.34 need to be executed as user lfs
# -----------------------------------------------------------------------------

ch5_4 () {
	echo "5.4 Binutils-2.30 - Pass 1"
    is_user lfs

	cd $LFS/sources
	tar -xf binutils-2.30.tar.xz	
	cd binutils-2.30

	mkdir -v build
	cd build
	../configure --prefix=/tools    \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
	     --disable-werror
	make
	case $(uname -m) in
		x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
	esac
	make install

	cd ../..
	rm -rf binutils-2.30
}

ch5_5 () {
	echo "5.5 GCC-7.3.0 - Pass 1"
    is_user lfs
    
	cd $LFS/sources
	tar -xf gcc-7.3.0.tar.xz
	cd gcc-7.3.0

	tar -xf ../mpfr-4.0.1.tar.xz
	mv -v mpfr-4.0.1 mpfr
	tar -xf ../gmp-6.1.2.tar.xz
	mv -v gmp-6.1.2 gmp
	tar -xf ../mpc-1.1.0.tar.gz
	mv mpc-1.1.0 mpc
	for file in gcc/config/{linux,i386/linux{,64}}.h;
	do
		cp -uv $file{,.orig};
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g'\
		    -e 's@/usr@/tools@g' $file.orig > $file;
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file;
		touch $file.orig;
	done		
	case $(uname -m) in
	    x86_64)
		    sed -e '/m64=/s/lib64/lib/' \
		    	-i.orig gcc/config/i386/t-linux64;
		    ;;
    	esac

	mkdir -v build
	cd       build
	../configure                                       \
	    --target=$LFS_TGT                              \
	    --prefix=/tools                                \
	    --with-glibc-version=2.11                      \
	    --with-sysroot=$LFS                            \
	    --with-newlib                                  \
	    --without-headers                              \
	    --with-local-prefix=/tools                     \
	    --with-native-system-header-dir=/tools/include \
	    --disable-nls                                  \
	    --disable-shared                               \
	    --disable-multilib                             \
	    --disable-decimal-float                        \
	    --disable-threads                              \
	    --disable-libatomic                            \
	    --disable-libgomp                              \
	    --disable-libmpx                               \
	    --disable-libquadmath                          \
	    --disable-libssp                               \
	    --disable-libvtv                               \
	    --disable-libstdcxx                            \
	    --enable-languages=c,c++
	make
	make install

	cd ..
	rm -rf gcc-7.3.0
}

ch5_6 () {
	echo "5.6 Linux-4.15.3 API Headers"
    is_user lfs

	cd $LFS/sources
	tar -xf linux-4.15.3.tar.xz
	cd linux-4.15.3

	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	cp -rv dest/include/* /tools/include

	cd ..
	rm -rf linux-4.15.3
}

ch5_7 () {
	echo "5.7. Glibc-2.27"
    is_user lfs

	cd $LFS/sources
	tar -xf glibc-2.27.tar.xz
	cd glibc-2.27

	mkdir -v build
	cd build/
	../configure \
		--prefix=/tools \
		--host=$LFS_TGT \
		--build=$(../scripts/config.guess) \
		--enable-kernel=3.2 \
		--with-headers=/tools/include \
		libc_cv_forced_unwind=yes \
		libc_cv_c_cleanup=yes
	make
	make install
	echo 'int main(){}' > dummy.c
	$LFS_TGT-gcc dummy.c
	readelf -l a.out | grep ': /tools'

	cd ../..
	rm -rf glibc-2.27
}

ch5_8 () {
	echo "5.8. Libstdc++-7.3.0"
    is_user lfs

	cd $LFS/sources
	tar -xf gcc-7.3.0.tar.xz
	cd gcc-7.3.0

	mkdir -v build
	cd build/
	../libstdc++-v3/configure \
		--host=$LFS_TGT \
		--prefix=/tools \
		--disable-multilib \
		--disable-nls \
		--disable-libstdcxx-threads \
		--disable-libstdcxx-pch \
		--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/7.3.0
	make
	make install

	cd ../..
	rm -rf gcc-7.3.0
}

ch5_9 () {
	echo "5.9. Binutils-2.30 - Pass 2"
    is_user lfs

	cd $LFS/sources
	tar -xf binutils-2.30.tar.xz
	cd binutils-2.30

	mkdir -v build
	cd build
	CC=$LFS_TGT-gcc \
	AR=$LFS_TGT-ar \
	RANLIB=$LFS_TGT-ranlib \
	../configure \
		--prefix=/tools \
		--disable-nls \
		--disable-werror \
		--with-lib-path=/tools/lib \
		--with-sysroot
	make
	make install
	make -C ld clean
	make -C ld LIB_PATH=/usr/lib:/lib
	cp -v ld/ld-new /tools/bin

	cd ../..
	rm -rf binutils-2.30
}

ch5_10 () {
	echo "5.10. GCC-7.3.0 - Pass 2"
    is_user lfs

	cd $LFS/sources
	tar -xf gcc-7.3.0.tar.xz
	cd gcc-7.3.0

	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
		`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
	for file in gcc/config/{linux,i386/linux{,64}}.h;
	do
		cp -uv $file{,.orig};
	      	sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' $file.orig > $file
	      	echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
		touch $file.orig
	done
	case $(uname -m) in
	      	x86_64)
		    	sed -e '/m64=/s/lib64/lib/' \
				-i.orig gcc/config/i386/t-linux64
     		;;
	esac
	tar -xf ../mpfr-4.0.1.tar.xz
	mv -v mpfr-4.0.1 mpfr
	tar -xf ../gmp-6.1.2.tar.xz
	mv -v gmp-6.1.2 gmp
	tar -xf ../mpc-1.1.0.tar.gz
	mv -v mpc-1.1.0 mpc
	mkdir -v build
	cd build
	CC=$LFS_TGT-gcc \
	CXX=$LFS_TGT-g++ \
	AR=$LFS_TGT-ar \
	RANLIB=$LFS_TGT-ranlib \
	../configure \
		--prefix=/tools \
		--with-local-prefix=/tools \
		--with-native-system-header-dir=/tools/include \
		--enable-languages=c,c++ \
		--disable-libstdcxx-pch \
		--disable-multilib \
		--disable-bootstrap \
		--disable-libgomp
	make
	make install
	ln -sv gcc /tools/bin/cc

	echo 'int main(){}' > dummy.c
	cc dummy.c
	readelf -l a.out | grep interpreter

	cd ../..
	rm -rf gcc-7.3.0
}

ch5_11 () {
	echo "5.11. Tcl-core-8.6.8"
    is_user lfs

	cd $LFS/sources
	tar -xf tcl8.6.8-src.tar.gz
	cd tcl8.6.8/unix

	./configure --prefix=/tools
	make
	TZ=UTC make test
	make install
	chmod -v u+w /tools/lib/libtcl8.6.so
	make install-private-headers
	ln -sv tclsh8.6 /tools/bin/tclsh

	cd ../..
	rm -rf tcl8.6.8
}

ch5_12 () {
	echo "5.12. Expect-5.45.4"
    is_user lfs

	cd $LFS/sources
	tar -xf expect5.45.4.tar.gz
	cd expect5.45.4

	cp -v configure{,.orig}
	sed 's:/usr/local/bin:/bin:' configure.orig > configure
	./configure --prefix=/tools \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
	make
	make test
	make SCRIPTS="" install

	cd ..
	rm -rf expect5.45.4
}

ch5_13 () {
	echo "5.13. DejaGNU-1.6.1"
    is_user lfs

	cd $LFS/sources
	tar -xf dejagnu-1.6.1.tar.gz
	cd dejagnu-1.6.1

	./configure --prefix=/tools
	make install
	make check

	cd ..
	rm -rf dejagnu-1.6.1
}

ch5_14 () {
	echo "5.14. M4-1.4.18"
    is_user lfs

	cd $LFS/sources
	tar -xf m4-1.4.18.tar.xz
	cd m4-1.4.18

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf m4-1.4.18
}

ch5_15 () {
	echo "5.15. Ncurses-6.1"
    is_user lfs

	cd $LFS/sources
	tar -xf ncurses-6.1.tar.gz
	cd ncurses-6.1

	sed -i s/mawk// configure
	./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
	make
	make install

	cd ..
	rm -rf ncurses-6.1
}

ch5_16 () {
	echo "5.16. Bash-4.4.18"
    is_user lfs

	cd $LFS/sources
	tar -xf bash-4.4.18.tar.gz
	cd bash-4.4.18

	./configure --prefix=/tools --without-bash-malloc
	make
	make tests
	make install
	ln -sv bash /tools/bin/sh

	cd ..
	rm -rf bash-4.4.18
}

ch5_17 () {
	echo "5.17. Bison-3.0.4"
    is_user lfs

	cd $LFS/sources
	tar -xf bison-3.0.4.tar.xz
	cd bison-3.0.4

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf bison-3.0.4
}

ch5_18 () {
	echo "5.18. Bzip2-1.0.6"
    is_user lfs

	cd $LFS/sources
	tar -xf bzip2-1.0.6.tar.gz
	cd bzip2-1.0.6

	make
	make PREFIX=/tools install

	cd ..
	rm -rf bzip2-1.0.6
}

ch5_19 () {
	echo "5.19. Coreutils-8.29"
    is_user lfs

	cd $LFS/sources
	tar -xf coreutils-8.29.tar.xz
	cd coreutils-8.29

	./configure --prefix=/tools --enable-install-program=hostname
	make
	make RUN_EXPENSIVE_TESTS=yes check
	# WARNING: ONE FAIL
	make install

	cd ..
	rm -rf coreutils-8.29
}

ch5_20 () {
	echo "5.20. Diffutils-3.6"
    is_user lfs

	cd $LFS/sources
	tar -xf diffutils-3.6.tar.xz
	cd diffutils-3.6

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf diffutils-3.6
}

ch5_21 () {
	echo "5.21. File-5.32"
    is_user lfs

	cd $LFS/sources
	tar -xf file-5.32.tar.gz
	cd file-5.32

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf file-5.32
}

ch5_22 () {
	echo "5.22. Findutils-4.6.0"
    is_user lfs

	cd $LFS/sources
	tar -xf findutils-4.6.0.tar.gz
	cd findutils-4.6.0

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf findutils-4.6.0.tar.gz
}

ch5_23 () {
	echo "5.23. Gawk-4.2.0"
    is_user lfs

	cd $LFS/sources
	tar -xf gawk-4.2.0.tar.xz
	cd gawk-4.2.0

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf gawk-4.2.0
}

ch5_24 () {
	echo "5.24. Gettext-0.19.8.1"
    is_user lfs

	cd $LFS/sources
	tar -xf gettext-0.19.8.1.tar.xz
	cd gettext-0.19.8.1

	cd gettext-tools
	EMACS="no" ./configure --prefix=/tools --disable-shared
	make -C gnulib-lib
	make -C intl pluralx.c
	make -C src msgfmt
	make -C src msgmerge
	make -C src xgettext
	cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

	cd ../..
	rm -rf gettext-0.19.8.1
}

ch5_25 () {
	echo "5.25. Grep-3.1"
    is_user lfs

	cd $LFS/sources
	tar -xf grep-3.1.tar.xz
	cd grep-3.1

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf grep-3.1
}

ch5_26 () {
	echo "5.26. Gzip-1.9"
    is_user lfs

	cd $LFS/sources
	tar -xf gzip-1.9.tar.xz
	cd gzip-1.9

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf gzip-1.9
}

ch5_27 () {
	echo "5.27. Make-4.2.1"
    is_user lfs

	cd $LFS/sources
	tar -xf make-4.2.1.tar.bz2
	cd make-4.2.1

	sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
	./configure --prefix=/tools --without-guile
	make
	make check
	make install

	cd ..
	rm -rf make-4.2.1
}

ch5_28 () {
	echo "5.28. Patch-2.7.6"
    is_user lfs

	cd $LFS/sources
	tar -xf patch-2.7.6.tar.xz
	cd patch-2.7.6

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf patch-2.7.6
}

ch5_29 () {
	echo "5.29. Perl-5.26.1"
    is_user lfs

	cd $LFS/sources
	tar -xf perl-5.26.1.tar.xz
	cd perl-5.26.1

	sh Configure -des -Dprefix=/tools -Dlibs=-lm
	make
	cp -v perl cpan/podlators/scripts/pod2man /tools/bin
	mkdir -pv /tools/lib/perl5/5.26.1
	cp -Rv lib/* /tools/lib/perl5/5.26.1

	cd ..
	rm -rf perl-5.26.1
}

ch5_30 () {
	echo "5.30. Sed-4.4"
    is_user lfs

	cd $LFS/sources
	tar -xf sed-4.4.tar.xz
	cd sed-4.4

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf sed-4.4
}

ch5_31 () {
	echo "5.31. Tar-1.30"
    is_user lfs

	cd $LFS/sources
	tar -xf tar-1.30.tar.xz
	cd tar-1.30

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf tar-1.30
}

ch5_32 () {
	echo "5.32. Texinfo-6.5"
    is_user lfs

	cd $LFS/sources
	tar -xf texinfo-6.5.tar.xz
	cd texinfo-6.5

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf texinfo-6.5
}

ch5_33 () {
	echo "5.33. Util-linux-2.31.1"
    is_user lfs

	cd $LFS/sources
	tar -xf util-linux-2.31.1.tar.xz
	cd util-linux-2.31.1

	./configure --prefix=/tools        \
            --without-python               \
            --disable-makeinstall-chown    \
            --without-systemdsystemunitdir \
            --without-ncurses              \
            PKG_CONFIG=""
	make
	make install

	cd ..
	rm -rf util-linux-2.31.1
}

ch5_34 () {
	echo "5.34. Xz-5.2.3"
    is_user lfs

	cd $LFS/sources
	tar -xf xz-5.2.3.tar.xz
	cd xz-5.2.3

	./configure --prefix=/tools
	make
	make check
	make install

	cd ..
	rm -rf xz-5.2.3
}

# -----------------------------------------------------------------------------
# Stripping unneeded symbols and changing ownership of $LFS/tools
# -----------------------------------------------------------------------------

# Stripping unneeded symbols
ch5_35 () {
	echo "5.35. Stripping"
    is_user lfs

	# Remove debugging symbols
	strip --strip-debug /tools/lib/*
	/usr/bin/strip --strip-unneeded /tools/{,s}bin/*

	# Remove documentation
	rm -rf /tools/{,share}/{info,man,doc}

	# Remove unneeded files
	find /tools/{lib,libexec} -name \*.la -delete
}

# Changing ownership of $LFS/tools
ch5_36 () {
	echo "5.36. Changing Ownership"

	# Check if user is root
    is_user root

    # This does not work for some reason
	chown -R root:root $LFS/tools
}

ch6_2 () {
	# Check if user is root
    is_user root

	echo "6.2. Preparing Virtual Kernel File Systems"
    mkdir -pv $LFS/{dev,proc,sys,run}

	echo "6.2.1. Creating Initial Device Nodes"
    mknod -m 600 $LFS/dev/console c 5 1
    mknod -m 666 $LFS/dev/null c 1 3

	echo "6.2.2. Mounting and Populating /dev"
    mount -v --bind /dev $LFS/dev

	echo "6.2.3. Mounting Virtual Kernel File Systems"
    mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
    mount -vt proc proc $LFS/proc
    mount -vt sysfs sysfs $LFS/sys
    mount -vt tmpfs tmpfs $LFS/run
    if [ -h $LFS/dev/shm ]; then
        mkdir -pv $LFS/$(readlink $LFS/dev/shm)
    fi
}

ch6_4 () {
	# Check if user is root
    is_user root

    chroot "$LFS" /tools/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
    /tools/bin/bash --login +h
}

ch6_7 () {
    echo "6.7. Linux-4.15.3 API Headers"

	cd /sources
	tar -xf linux-4.15.3.tar.xz
	cd linux-4.15.3

    make mrproper
    make INSTALL_HDR_PATH=dest headers_install
    find dest/include \( -name .install -o -name ..install.cmd \) -delete
    cp -rv dest/include/* /usr/include

	cd ..
	rm -rf linux-4.15.3
}

ch6_8 () {
    echo "6.8. Man-pages-4.15"

	cd /sources
	tar -xf man-pages-4.15.tar.xz
	cd man-pages-4.15

    make install

	cd ..
	rm -rf man-pages-4.15
}

ch6_9 () {
    echo "6.9. Glibc-2.27"

	cd /sources
	tar -xf glibc-2.27.tar.xz
	cd glibc-2.27

    patch -Np1 -i ../glibc-2.27-fhs-1.patch
    ln -sfv /tools/lib/gcc /usr/lib
    case $(uname -m) in
        i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/7.3.0/include
                ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
        ;;
        x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/7.3.0/include
                ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
        ;;
    esac
    rm -f /usr/include/limits.h
    mkdir -v build
    cd       build
    CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
    ../configure --prefix=/usr                          \
                 --disable-werror                       \
                 --enable-kernel=3.2                    \
                 --enable-stack-protector=strong        \
                 libc_cv_slibdir=/lib
    unset GCC_INCDIR
    make
    make check
    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
    make install
    cp -v ../nscd/nscd.conf /etc/nscd.conf
    mkdir -pv /var/cache/nscd
    mkdir -pv /usr/lib/locale
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030
    make localedata/install-locales

    echo "6.9.2. Configuring Glibc"
    cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
    tar -xf ../../tzdata2018c.tar.gz
    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}
    for tz in etcetera southamerica northamerica europe africa antarctica  \
              asia australasia backward pacificnew systemv; do
        zic -L /dev/null   -d $ZONEINFO       -y "sh yearistype.sh" ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz}
        zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz}
    done
    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO
    cp -v /usr/share/zoneinfo/America/North_Dakota/Center /etc/localtime
    cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
   cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
    mkdir -pv /etc/ld.so.conf.d 

	cd ../..
	rm -rf glibc-2.27
}

ch6_10 () {
    echo "6.10. Adjusting the Toolchain"

    mv -v /tools/bin/{ld,ld-old}
    mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
    mv -v /tools/bin/{ld-new,ld}
    ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
    gcc -dumpspecs | sed -e 's@/tools@@g'                   \
        -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
        -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
        `dirname $(gcc --print-libgcc-file-name)`/specs
    echo 'int main(){}' > dummy.c
    cc dummy.c -v -Wl,--verbose &> dummy.log
    readelf -l a.out | grep ': /lib'
    grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
    grep -B1 '^ /usr/include' dummy.log
    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
    grep "/lib.*/libc.so.6 " dummy.log
    grep found dummy.log
    rm -v dummy.c a.out dummy.log
}

#ch5_4
#ch5_5
#ch5_6
#ch5_7
#ch5_8
#ch5_9
#ch5_10
#ch5_11
#ch5_12
#ch5_13
#ch5_14
#ch5_15
#ch5_16
#ch5_17
#ch5_18
#ch5_19
#ch5_20
#ch5_21
#ch5_22
#ch5_23
#ch5_24
#ch5_25
#ch5_26
#ch5_27
#ch5_28
#ch5_29
#ch5_30
#ch5_31
#ch5_32
#ch5_33
#ch5_34
#ch5_35
#ch5_36
#ch6_2
#ch6_4
#ch6_7
#ch6_8
#ch6_9
ch6_10
