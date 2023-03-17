#!/usr/bin/env bash

# exit on errors
set -e

# everything will reside under this prefix
PREFIX=$PWD/cheese
PREFIX_OPENSSL=$PREFIX/openssl
#PREFIX_NGINX=/usr/local/nginx
PREFIX_NGINX=$PREFIX/nginx

echo -e "This will build and install nginx at:\n"
echo -e "  $PREFIX_NGINX\n"

# request confirmation to install
while [[ ! $REPLY =~ ^[nNyY]$ ]] ; do read -rp "Start installation? [y/n] "; done
[[ $REPLY =~ ^[nN]$ ]] && exit 0

echo -e "\nInitializing Git submodules...\n"
git submodule update --init
git submodule --quiet foreach 'printf "%-10s %s\n" $name: `git describe --tags 2>/dev/null || echo -`'

# use all cpu cores to build quicker
MAKE_JOBS=`sysctl -n hw.ncpu`

if [[ ! (-e $PREFIX_OPENSSL/include/openssl) ]] ; then
  echo -e "\nConfiguring openssl...\n"
  cd src/openssl
  ./config --prefix=$PREFIX_OPENSSL no-shared no-threads

  echo -e "\nBuilding openssl...\n"
  make 1>/dev/null --quiet --jobs=$MAKE_JOBS

  echo -e "\nInstalling openssl...\n"
  make --quiet install_sw

  cd ../..
fi

echo -e "\nConfiguring nginx...\n"
cd src/nginx
ln -sf auto/configure configure
./configure \
  --prefix=$PREFIX_NGINX \
  --http-client-body-temp-path=$PREFIX_NGINX/temp/client_body \
  --http-proxy-temp-path=$PREFIX_NGINX/temp/proxy \
  --with-cc-opt="-I$PREFIX_OPENSSL/include -O2 -pipe -fPIE -fPIC -Werror=format-security -D_FORTIFY_SOURCE=2" \
  --with-ld-opt="-L$PREFIX_OPENSSL/lib" \
  --with-http_realip_module \
  --with-http_ssl_module \
  --with-http_v2_module \
  --without-http_fastcgi_module \
  --without-http_scgi_module \
  --without-http_uwsgi_module \
  ;

echo -e "\nBuilding nginx...\n"
make 1>/dev/null --quiet --jobs=$MAKE_JOBS

echo -e "\nInstalling nginx..."
# mv -f conf{,-MOVED}
make --quiet install
# mv -f conf{-MOVED,}
mkdir -p $PREFIX_NGINX/temp

cd ../..

# cleanup git's newly create submodule files
# you can disable this if repeatedly building or changing nginx's ./configure
echo -e "Cleaning up...\n"
git submodule foreach git clean -qfd 1>/dev/null

RELATIVE_PATH=${PREFIX_NGINX#$PWD/}
cat <<end
╔═══════════════════════════════════════════════════════════════════════════════
║
║   🎉  Nginx was successfully built. Test with these commands:
║
║           $RELATIVE_PATH/sbin/nginx -t
║           $RELATIVE_PATH/sbin/nginx -V
║
╚═══════════════════════════════════════════════════════════════════════════════
end
