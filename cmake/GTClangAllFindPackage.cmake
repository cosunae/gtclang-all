##===------------------------------------------------------------------------------*- CMake -*-===##
##                         _       _
##                        | |     | |
##                    __ _| |_ ___| | __ _ _ __   __ _ 
##                   / _` | __/ __| |/ _` | '_ \ / _` |
##                  | (_| | || (__| | (_| | | | | (_| |
##                   \__, |\__\___|_|\__,_|_| |_|\__, | - GridTools Clang DSL
##                    __/ |                       __/ |
##                   |___/                       |___/
##
##
##  This file is distributed under the MIT License (MIT). 
##  See LICENSE.txt for details.
##
##===------------------------------------------------------------------------------------------===##

include(CMakeParseArguments)
include(GTClangAddOptionalDeps)
include(GTClangAllMakePackageInfo)

# gtclang_all_find_package
# ------------------------
#
# Try to find the package <PACKAGE>. If the package cannot be found via find_package, the 
# file "External_<PACKAGE>" will be included which should define a target <PACKAGE> (in all 
# lower case) which is used to built the package.
#
# The option USE_SYSTEM_<PACKAGE> indicates if the <PACKAGE> (all uppercase) is built or 
# supplied by the system. Note that USE_SYSTEM_<PACKAGE> does not honor the user setting if 
# the package cannot be found (i.e it will build it regardlessly).
#
#    PACKAGE:STRING=<>       - Name of the package (has to be the same name as used in 
#                              find_package).
#    PACKAGE_ARGS:LIST=<>    - Arguments passed to find_package.
#    FORWARD_VARS:LIST=<>    - List of variables which are appended (if defined) to the 
#                              GTCLANG_ALL_THIRDPARTY_CMAKE_ARGS. This are usually the variables 
#                              which have an effect on the find_package call. For example, we may 
#                              want to forward BOOST_ROOT if it was supplied by the user. 
#    REQUIRED_VARS:LIST=<>   - Variables which need to be TRUE to consider the package as 
#                              found. By default we check that ``<PACKAGE>_FOUND`` is TRUE.
#    DEPENDS:LIST=<>         - Dependencies of this package.
#
macro(gtclang_all_find_package)
  set(options)
  set(one_value_args PACKAGE)
  set(multi_value_args PACKAGE_ARGS FORWARD_VARS REQUIRED_VARS DEPENDS)
  cmake_parse_arguments(ARG "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

  if(NOT("${ARG_UNPARSED_ARGUMENTS}" STREQUAL ""))
    message(FATAL_ERROR "invalid argument ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  string(TOUPPER ${ARG_PACKAGE} package_upper)

  # Define the external file to include if we cannot find the package
  set(external_file External_${ARG_PACKAGE})

  # Define the name of the target *if* we built it (targets are always lower-case for us)
  string(TOLOWER ${ARG_PACKAGE} target)

  # Do we use the system package or build it from source? 
  set(doc "Should we use the system ${ARG_PACKAGE}?")
  set(default_use_system ON)
  if(NO_SYSTEM_LIBS)
    set(default_use_system OFF)
  endif()

  option(USE_SYSTEM_${package_upper} ${doc} ${default_use_system})

  set(use_system FALSE)
  if(NOT(USE_SYSTEM_${package_upper}))
    set(USE_SYSTEM_${package_upper} OFF CACHE BOOL ${doc} FORCE)
    include(${external_file})
  else()
    # Check if the system has the package
    find_package(${ARG_PACKAGE} ${ARG_PACKAGE_ARGS})

    # Check if all the required variables are set
    set(required_vars_ok TRUE)
    set(missing_required_vars)
    foreach(arg ${ARG_REQUIRED_VARS})
      if(NOT(${arg}))
        set(required_vars_ok FALSE)
        set(missing_required_vars "${missing_required_vars} ${arg}")
      endif()
    endforeach()

    if(missing_required_vars)
      message(STATUS "Package ${ARG_PACKAGE} not found due to missing:${missing_required_vars}")    
    endif()
    
    if(required_vars_ok AND (${ARG_PACKAGE}_FOUND OR ${ARG_PACKAGE}_DIR)) 
      set(use_system TRUE)

      # Forward arguments
      foreach(var ${ARG_FORWARD_VARS})
        if(DEFINED ${var})
          set(GTCLANG_ALL_THIRDPARTY_CMAKE_ARGS 
              "${GTCLANG_ALL_THIRDPARTY_CMAKE_ARGS};-D${var}:PATH=${${var}}")
        endif()
      endforeach()

    else()
      set(USE_SYSTEM_${package_upper} OFF CACHE BOOL ${doc} FORCE)
      include(${external_file})
    endif()
  endif()

  # Set the dependencies if we build
  if(NOT(use_system) AND ARG_DEPENDS)
    set(deps)
    gtclang_all_add_optional_deps(deps ${ARG_DEPENDS})
    if(deps)
      add_dependencies(${target} ${deps})
    endif()
  endif()

  gtclang_all_make_package_info(${ARG_PACKAGE} ${use_system})
endmacro()
