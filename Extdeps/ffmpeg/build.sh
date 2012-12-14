#!/bin/sh

#  build.sh
#  ffmpeg
#
#  Created by Dmitry Promsky on 1/16/12.
#  Copyright 2012 dmitry.promsky@gmail.com. All rights reserved.

set -e -u -o pipefail

export LDFLAGS="-headerpad_max_install_names"

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
  export PATH="$PATH:/usr/local/bin:/opt/local/bin" 
  for arch in $ARCHS
  do
    echo "Building for $arch"
    compiler="clang"
    if [ "i386" == "$arch" ]
    then
      compiler="clang -arch i386"
    elif [ "x86_64" == "$arch" ]
    then
      compiler="clang -arch x86_64"
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
      --enable-shared \
      --arch=$arch \
      --enable-cross-compile \
      --target-os=darwin \
      --cc="$compiler" \
      --disable-everything \
      --enable-bsf=mp3_header_compress \
      --enable-bsf=mp3_header_decompress \
      --enable-demuxer=ape \
      --enable-demuxer=asf \
      --enable-demuxer=mp3 \
      --enable-demuxer=xwma \
      --enable-decoder=ape \
      --enable-decoder=mp3 \
      --enable-decoder=mp3adu \
      --enable-decoder=mp3adufloat \
      --enable-decoder=mp3float \
      --enable-decoder=mp3on4 \
      --enable-decoder=mp3on4float \
      --enable-decoder=wmalossless \
      --enable-decoder=wmapro \
      --enable-decoder=wmav1 \
      --enable-decoder=wmav2 \
      --enable-decoder=wmavoice \
      --enable-parser=aac \
      --enable-parser=aac_latm \
      --enable-parser=ac3 \
      --enable-parser=mpegaudio \
      --enable-protocol=file

    # FFmpeg's configure script will try to link to SDL,
    # even though nothing requires it in the config above.
    #
    # Work around that by hackishly modifying config.mak 
    # (using unholy regexps of doom!) after it's been generated.
    perl -pi -e 's/-lSDLmain -lSDL//' config.mak
    perl -pi -e 's/SDL_LIBS=.*$/SDL_LIBS=/' config.mak
    perl -pi -e 's/SDL_CFLAGS=.*$/SDL_CFLAGS=/' config.mak

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
