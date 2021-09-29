# Building ONLPv2 on Ubuntu

This repository is a work in progress, but it demonstrates that it may be
possible to build ONLP separately to ONL, and do so for the Ubuntu operating
system. It currently uses a staging branch on APS Network's own GitHub (the 
platform sources are not available on the main ONL repository anyway). 

The technique applies as equally to ONLP (v1).

The ONL build system is not terribly well understood, but Mion
(NetworkGradeLinux) developed recipes to build it outside of the ordinary 
ONL build process.[1]


## Patches

There are both patches to the core library and to platform specific code. 
The platform patches are placed in a subdirectory named after the platform name
and are applied on this basis in the build script; all of the patches in that
directory are applied, regardless of their name.

The ordinary patches are for adding `i2c` linker options to the build, some
better error logging and pulling in the correct `editline` library.

The platform patch changes a Makefile variable which isn't well understood, but
is required to build.


[1]: https://github.com/NetworkGradeLinux/meta-mion/blob/dunfell/recipes-platform/onlpv2/onlpv2_1.0.bb