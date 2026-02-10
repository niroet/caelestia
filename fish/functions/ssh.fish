function ssh --wraps ssh --description 'SSH with TERM=xterm-256color, remote .bashrc swap, remote zellij auto-install + persistent attach, and always recopy zellij config + themes'
    # ----------------------------
    # Settings you might tweak
    # ----------------------------
    set -l session main
    set -l remote_zj '$HOME/.local/bin/zellij'   # IMPORTANT: keep $HOME unexpanded locally

    set -l local_zellij_cfg ~/.config/zellij/config.kdl
    set -l local_zellij_themes_dir ~/.config/zellij/themes

    # If local zellij isn't installed, we fall back to this version:
    set -l fallback_zellij_version 0.43.1
    set -l ssh_opts "-o StrictHostKeyChecking=no"

    # ----------------------------
    # Parse SSH args to find host (first non-option argument)
    # ----------------------------
    set -l host ""
    set -l i 1
    set -l argc (count $argv)

    while test $i -le $argc
        set -l a $argv[$i]

        if test "$a" = "--"
            set i (math $i + 1)
            break
        end

        if string match -qr '^-' -- $a
            # Options that take a following argument
            switch $a
                case -p -l -i -F -J -o -b -c -D -E -L -R -S -W -w
                    set i (math $i + 2)
                    continue
                case '*'
                    set i (math $i + 1)
                    continue
            end
        else
            set host $a
            break
        end
    end

    if test -z "$host"
        echo "ssh wrapper error: could not determine host from arguments: $argv" >&2
        return 2
    end

    # ----------------------------
    # Figure out which zellij version to install remotely (match local)
    # ----------------------------
    set -l local_ver (command zellij --version 2>/dev/null | string split ' ')[2]
    if test -z "$local_ver"
        set local_ver $fallback_zellij_version
    end

    # ----------------------------
    # Backup remote .bashrc and rsync local .bashrc up
    # ----------------------------
    command ssh $ssh_opts $host 'cp ~/.bashrc ~/.bashrc.backup' 2>/dev/null
    if test $status -ne 0
        echo "Failed to backup .bashrc on $host" >&2
    end

    rsync -e "ssh $ssh_opts" ~/.bashrc $host:~/.bashrc

    # ----------------------------
    # Always recopy zellij config + themes to remote
    # ----------------------------
    command ssh $ssh_opts $host 'mkdir -p ~/.config/zellij/themes' 2>/dev/null

    if test -f $local_zellij_cfg
        rsync -e "ssh $ssh_opts" $local_zellij_cfg $host:~/.config/zellij/config.kdl
    else
        echo "Warning: local zellij config not found at $local_zellij_cfg (skipping copy)" >&2
    end

    if test -d $local_zellij_themes_dir
        # Trailing slash copies contents into the destination directory
        rsync -a --delete -e "ssh $ssh_opts" $local_zellij_themes_dir/ $host:~/.config/zellij/themes/
    else
        echo "Warning: local zellij themes dir not found at $local_zellij_themes_dir (skipping copy)" >&2
    end

    # ----------------------------
    # Ensure remote zellij exists (correct arch), then attach/create session
    # ----------------------------
    set -l install_cmd "
set -eu

# Already installed?
if [ -x $remote_zj ]; then
  exit 0
fi

os=\$(uname -s 2>/dev/null || echo unknown)
arch=\$(uname -m 2>/dev/null || echo unknown)

if [ \"\$os\" != \"Linux\" ]; then
  echo \"Remote OS '\$os' not supported (this installer only handles Linux).\" >&2
  exit 2
fi

case \"\$arch\" in
  x86_64|amd64) target='x86_64-unknown-linux-musl' ;;
  aarch64|arm64) target='aarch64-unknown-linux-musl' ;;
  *)
    echo \"Remote arch '\$arch' not supported by this installer.\" >&2
    exit 3
    ;;
esac

ver='$local_ver'
url=\"https://sourceforge.net/projects/zellij.mirror/files/v\${ver}/zellij-\${target}.tar.gz/download\"

mkdir -p \"\$HOME/.local/bin\" \"\$HOME/.cache/zellij/\$ver\"
cd \"\$HOME/.cache/zellij/\$ver\"

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fL \"\$url\" -o zellij.tgz
  elif command -v wget >/dev/null 2>&1; then
    wget -O zellij.tgz \"\$url\"
  else
    echo \"Need curl or wget on remote to download zellij.\" >&2
    exit 4
  fi
}

fetch
tar -xzf zellij.tgz
chmod +x zellij
mv -f zellij \"\$HOME/.local/bin/zellij\"
"

    # Install (if needed)
    command ssh $ssh_opts $host "$install_cmd"
    if test $status -ne 0
        echo "Remote zellij install failed on $host" >&2
        # Still try to restore bashrc before returning
        command ssh $ssh_opts $host 'mv ~/.bashrc.backup ~/.bashrc' 2>/dev/null
        return 1
    end

    # Attach/create persistent session
    TERM=xterm-256color command ssh -t $ssh_opts $argv "$remote_zj attach --create $session"

    # ----------------------------
    # Restore original .bashrc
    # ----------------------------
    command ssh $ssh_opts $host 'mv ~/.bashrc.backup ~/.bashrc' 2>/dev/null
    if test $status -ne 0
        echo "Failed to restore .bashrc on $host" >&2
    end
end
