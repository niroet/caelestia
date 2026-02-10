set -gx EDITOR vim
set -gx VISUAL vim
set -gx BROWSER /opt/zen-browser-bin/zen-bin

# Ensure fish cache dir is sane to avoid /generated_completions writes.
if not set -q __fish_cache_dir; or test -z "$__fish_cache_dir"
    if not set -q XDG_CACHE_HOME; or test -z "$XDG_CACHE_HOME"
        set -gx XDG_CACHE_HOME $HOME/.cache
    end
    set -g __fish_cache_dir "$XDG_CACHE_HOME/fish"
end

if status is-interactive
    # Starship custom prompt
    # starship init fish | source

    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish | source
    
    # Custom cd function to clear screen when cd is used without arguments
    # This must come after zoxide init to properly override it
    function cd --wraps cd --description 'Change directory and clear screen if no arguments'
        if test (count $argv) -eq 0
            # If no arguments, cd to home and clear
            builtin cd
            clear
        else
            # Otherwise, use zoxide's z function
            z $argv
        end
    end

    # Better ls
    alias ls='eza --icons --group-directories-first -1 --ignore-glob="desktop.ini"'
    alias c='clear'
    
    # Abbrs
    abbr gd 'git diff'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'

    abbr st 'rg --no-heading --line-number --color=always "" | fzf --ansi --exact'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    # Custom colours
    cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    # # For jumping between prompts in foot terminal
    # function mark_prompt_start --on-event fish_prompt
    #     echo -en "\e]133;A\e\\"
    # end
end
set -gx GPG_TTY (tty)

thefuck --alias | source
