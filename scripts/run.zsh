#!/usr/bin/env zsh

setopt err_exit

# Download NaPTAN if necessary
naptan_path=/tmp/naptan.zip

rail_reference=/tmp/naptan/RailReferences.csv

if [[ ! -a "${rail_reference}" ]]; then
    curl -o "${naptan_path}" http://www.dft.gov.uk/NaPTAN/snapshot/NaPTANcsv.zip
    cd /tmp
    mkdir -p naptan
    cd naptan/
    unzip -o "${naptan_path}"
fi

cd ${0:h}/..
bundle exec ruby ./main.rb \
    --config ./local/config.json \
    --naptan-csv "${rail_reference}" \
    "${@}"

