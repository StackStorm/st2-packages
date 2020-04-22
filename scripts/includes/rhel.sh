install_yum_utils() {
  # We need repoquery tool to get package_name-package_ver-package_rev in RPM based distros
  # if we don't want to construct this string manually using yum info --show-duplicates and
  # doing a bunch of sed awk magic. Problem is this is not installed by default on all images.
  sudo yum install -y yum-utils
}


get_full_pkg_versions() {
  if [ "$VERSION" != '' ];
  then
    local RHMAJVER=`cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9.]\).*/\1/'`
    local REPOQUERY_FLAGS="--nvr --show-duplicates"
    if [ "$RHMAJVER" -ge "8" ]; then
      # RHEL 8 and newer, you need "-y" flag to avoid being prompted to confirm "yes"
      local REPOQUERY_FLAGS="-y ${REPOQUERY_FLAGS}"
    fi

    local ST2_VER=$(repoquery ${REPOQUERY_FLAGS} st2 | grep -F st2-${VERSION} | sort --version-sort | tail -n 1)
    if [ -z "$ST2_VER" ]; then
      echo "Could not find requested version of st2!!!"
      sudo repoquery ${REPOQUERY_FLAGS} st2
      exit 3
    fi
    ST2_PKG=${ST2_VER}

    local ST2MISTRAL_VER=$(repoquery ${REPOQUERY_FLAGS} st2mistral | grep -F st2mistral-${VERSION} | sort --version-sort | tail -n 1)
    # RHEL 8 and newer does not install Mistral
    if [ -z "$ST2MISTRAL_VER" -a "$RHMAJVER" -lt "8" ]; then
      echo "Could not find requested version of st2mistral!!!"
      sudo repoquery ${REPOQUERY_FLAGS} st2mistral
      exit 3
    fi
    ST2MISTRAL_PKG=${ST2MISTRAL_VER}

    local ST2WEB_VER=$(repoquery ${REPOQUERY_FLAGS} st2web | grep -F st2web-${VERSION} | sort --version-sort | tail -n 1)
    if [ -z "$ST2WEB_VER" ]; then
      echo "Could not find requested version of st2web."
      sudo repoquery ${REPOQUERY_FLAGS} st2web
      exit 3
    fi
    ST2WEB_PKG=${ST2WEB_VER}

    local ST2CHATOPS_VER=$(repoquery ${REPOQUERY_FLAGS} st2chatops | grep -F st2chatops-${VERSION} | sort --version-sort | tail -n 1)
    if [ -z "$ST2CHATOPS_VER" ]; then
      echo "Could not find requested version of st2chatops."
      sudo repoquery ${REPOQUERY_FLAGS} st2chatops
      exit 3
    fi
    ST2CHATOPS_PKG=${ST2CHATOPS_VER}

    echo "##########################################################"
    echo "#### Following versions of packages will be installed ####"
    echo "${ST2_PKG}"
    echo "${ST2MISTRAL_PKG}"
    echo "${ST2WEB_PKG}"
    echo "${ST2CHATOPS_PKG}"
    echo "##########################################################"
  fi
}
