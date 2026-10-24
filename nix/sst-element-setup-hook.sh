# shellcheck shell=bash
# Setup hook of SST element packages: make sst find the libraries through the
# conf fragment the package installs.  sst reads every file listed in
# SST_CONFIG_FILE_PATH (sst-core src/sst/core/env/envquery.cc).

addSstElementConf() {
    local conf="$1/etc/sst/@pname@.conf"
    if [[ -f "$conf" && ":${SST_CONFIG_FILE_PATH-}:" != *":$conf:"* ]]; then
        export SST_CONFIG_FILE_PATH="$conf${SST_CONFIG_FILE_PATH:+:$SST_CONFIG_FILE_PATH}"
    fi
}

addSstElementConf @out@
