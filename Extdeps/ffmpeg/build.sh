#!/bin/sh

#  build.sh
#  ffmpeg
#
#  Created by Dmitry Promsky on 1/16/12.
#  Copyright 2012 dmitry.promsky@gmail.com. All rights reserved.

set -e -u -o pipefail

if [ "clean" == "$ACTION" ]
then
  for lib in libavutil libavcodec libavformat
  do
    rm -f ${SRCROOT}/${lib}
  done
elif [ "" == "$ACTION" ] # xcode passes empty string for 'build' command
then

  [ -e ${SRCROOT}/libavutil ] && \
  [ -e ${SRCROOT}/libavcodec ] && \
  [ -e ${SRCROOT}/libavformat ] && \
  echo "Already built" && exit 0

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
      --cc="$compiler" \
      --enable-demuxer=ape \
      --enable-demuxer=xwma \
      --enable-decoder=ape \
      --enable-decoder=wmalossless \
      --enable-decoder=wmapro \
      --enable-decoder=wmav1 \
      --enable-decoder=wmav2 \
      --enable-decoder=wmavoice 
    make

    for lib in libavutil libavformat libavcodec
    do
      cp ${lib}/${lib}.dylib ${OBJROOT}/${lib}.dylib.${arch}
    done

    make distclean
  done

  # copy libs
  cd $OBJROOT
  for lib in libavutil libavformat libavcodec
  do
    lipo -create ${lib}.dylib.* -output ${SRCROOT}/${lib}
  done

fi
