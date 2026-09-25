#!/bin/bash

#create_symlinks() {
#    # Get the directory in which this script lives.
#    script_dir=$(dirname "$(readlink -f "$0")")
#
#    # Get a list of all files in this directory that start with a dot.
#    files=$(find -maxdepth 1 -type f -name ".*")

    # Create a symbolic link to each file in the home directory.
#    for file in $files; do
#        name=$(basename $file)
#        echo "Creating symlink to $name in home directory."
#        rm -rf ~/$name
#        ln -s $script_dir/$name ~/$name
#    done
#}

#create_symlinks
sudo chsh "$(id -un)" --shell "/usr/bin/zsh"
cat .zshrc > $HOME/.zshrc
cat .aliases > $HOME/.aliases

#install opencode
curl -fsSL https://opencode.ai/v2/install | bash

#install herder
curl -fsSL https://herdr.dev/install.sh | sh

# make freshly installed binaries visible to this script
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/bin:$PATH"

mkdir -p "$HOME/.config/opencode"
cd "$HOME" && herdr integration install opencode

npx --yes skills add herdrdev/herdr --skill herdr -g -a opencode -y
