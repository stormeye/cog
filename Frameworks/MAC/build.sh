#!/bin/sh

#  build.sh
#  ffmpeg
#
#  Created by Dmitry Promsky on 1/16/12.
#  Copyright 2012 dmitry.promsky@gmail.com. All rights reserved.

set -e -u -o pipefail

cd src
# adding /usr/local/bin to PATH so
# that yasm is found there
export PATH="$PATH:/usr/local/bin" 
for arch in $ARCHS
do
  echo "Building for $arch"
  compiler="clang"
  if [ "i386" == "$arch" ]
  then
    compiler="clang -m32"
  fi
  sh ./configure \
    --disable-doc \
    --disable-ffmpeg \
    --disable-ffplay \
    --disable-ffprobe \
    --disable-ffserver \
    --disable-avdevice \
    --disable-swresample \
    --disable-swscale \
    --disable-postproc \
    --disable-avfilter \
    --disable-network \
    --disable-encoders \
    --disable-muxers \
    --enable-shared \
    --disable-static \
    --disable-decoder=h264,svq3 \
    --disable-parser=h264 \
    --arch=$arch \
    --enable-cross-compile \
    --target-os=darwin \
    --cc="$compiler"
  make

  for lib in libavutil libavformat libavcodec
  do
    cp ${lib}/${lib}.dylib ${OBJROOT}/${lib}.dylib.${arch}
  done

  cp config.h ${OBJROOT}/config.h.${arch}
  cp libavutil/avconfig.h ${OBJROOT}/avconfig.h.${arch}

  make distclean
done


# create framework dirs
dstdir=${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}
headers=$dstdir/Versions/A/Headers
libs=$dstdir/Versions/A/Libraries
mkdir $headers
mkdir $libs

# copy architecture independent headers
for lib in libavutil libavformat libavcodec
do
  mkdir $headers/$lib
  cp $lib/*.h $headers/$lib
done

# copy libs
cd $OBJROOT
for lib in libavutil libavformat libavcodec
do
  lipo -create ${lib}.dylib.* -output ${lib}.dylib
done
cp libavcodec.dylib $dstdir/Versions/A/${PRODUCT_NAME}
cp libavutil.dylib libavformat.dylib $libs/

# copy architecture dependent headers
for arch in $ARCHS
do
  mkdir -p $headers/$arch/libavutil
  cp config.h.${arch} $headers/$arch/config.h
  cp avconfig.h.${arch} $headers/$arch/libavutil/avconfig.h
done

# make links
cd $dstdir
ln -s Versions/Current/Headers ./Headers
ln -s Versions/Current/Libraries ./Libraries
ln -s Versions/Current/${PRODUCT_NAME} ./${PRODUCT_NAME}

