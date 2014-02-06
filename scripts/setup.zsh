#!/usr/bin/env zsh

setopt err_exit

repo=${0:h}/..

# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

require_bundler=(
    .
)

pacman_packages=(
    git
    zsh
)


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function add_archlinuxfr_repo()
{
    if grep --quiet '\[archlinuxfr\]' /etc/pacman.conf; then
        return
    fi

    sudo tee --append /etc/pacman.conf <<-'EOF'
		[archlinuxfr]
		Server = http://repo.archlinux.fr/$arch
		SigLevel = Never
	EOF
}

function install_pacman_packages()
{
    sudo pacman --noconfirm --sync --needed --refresh $pacman_packages
}

function install_aur_packages()
{
    local package

    for package in $aur_packages; do
        if ! pacman -Q $package &> /dev/null; then
            yaourt --noconfirm --sync $package
        fi
    done
}

function install_rvm()
{
    # /etc/gemrc is part of Arch Linux's Ruby package
    if [[ -f /etc/gemrc ]]; then
        sudo sed -i '/gem: --user-install/d' /etc/gemrc
    fi

    curl --location https://get.rvm.io | bash -s stable
}

function install_ruby()
{
    rvm install ruby-$ruby_version
}

function install_gemset()
{
    rvm gemset create $ruby_gemset

    local dirname
    for dirname in $require_bundler; do
        bundle install --gemfile=$repo/$dirname/Gemfile
    done
}

function init_config()
{
    local_dir="${repo}/local"
    mkdir -p "${local_dir}"

    config_path="${local_dir}/config.json"

    if [[ ! -f ${config_path} ]]; then
        cp "${repo}/template/config.json" "${config_path}"
    fi
}


function manual()
{
    cat <<-'EOF'
		1) Fill in the config in local/config.json
	EOF
}

# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

tasks=(
    install_pacman_packages
    install_rvm
    install_ruby
    install_gemset
    init_config
    manual
)

function usage()
{
    cat <<-'EOF'
		Set up a development environment

		Usage:

		    setup.zsh [TASK...]

		Tasks:

		    install_pacman_packages
		    install_rvm
		    install_ruby
		    install_gemset
		    init_config
		    manual
	EOF
    exit 1
}

for task in $@; do
    if [[ ${tasks[(i)$task]} -gt ${#tasks} ]]; then
        usage
    fi
done

for task in ${@:-${tasks[@]}}; do
    print -P -- "%F{green}Task: $task%f"
    $task
done

