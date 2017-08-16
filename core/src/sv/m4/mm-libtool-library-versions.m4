dnl mm-libtool-library-versions.m4

dnl Set version numbers for libraries built with GNU Libtool.
dnl
dnl   MM_LIBTOOL_LIBRARY_VERSIONS(stem,current,revision,age)
dnl
AC_DEFUN([MM_LIBTOOL_LIBRARY_VERSIONS],
  [$1_VERSION_INTERFACE_CURRENT=$2
   $1_VERSION_INTERFACE_REVISION=$3
   $1_VERSION_INTERFACE_AGE=$4
   AC_DEFINE_UNQUOTED([$1_VERSION_INTERFACE],
     [$$1_VERSION_INTERFACE_CURRENT.$$1_VERSION_INTERFACE_REVISION.$$1_VERSION_INTERFACE_AGE],
     [current interface number])
   AC_DEFINE_UNQUOTED([$1_VERSION_INTERFACE_CURRENT],
     [$$1_VERSION_INTERFACE_CURRENT],
     [current interface number])
   AC_DEFINE_UNQUOTED([$1_VERSION_INTERFACE_REVISION],
     [$$1_VERSION_INTERFACE_REVISION],
     [current interface implementation number])
   AC_DEFINE_UNQUOTED([$1_VERSION_INTERFACE_AGE],
     [$$1_VERSION_INTERFACE_AGE],
     [current interface age number])
   AC_DEFINE_UNQUOTED([$1_VERSION_INTERFACE_STRING],
     ["$$1_VERSION_INTERFACE_CURRENT.$$1_VERSION_INTERFACE_REVISION"],
     [library interface version])
   AC_SUBST([$1_VERSION_INTERFACE_CURRENT])
   AC_SUBST([$1_VERSION_INTERFACE_REVISION])
   AC_SUBST([$1_VERSION_INTERFACE_AGE])])

dnl end of file