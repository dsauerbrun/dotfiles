# not really needed since I'm not installing additional scripts
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
