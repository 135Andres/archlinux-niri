# ~/.zshrc

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Historial de comandos
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory incappendhistory histignoredups

# Aliases modernos (con fallback si no están instalados)
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -la --icons --group-directories-first --git'
  alias tree='eza --tree --icons'
else
  alias ls='ls --color=auto'
  alias ll='ls -la'
fi
alias grep='grep --color=auto'

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

# Prompt (idéntico al que tenías en Bash en color amarillo)
PROMPT='%F{yellow}[%n@%m %1~]$%f '

# Zoxide (cd inteligente con 'z')
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# FZF (búsqueda difusa de comandos con Ctrl+R y archivos)
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh 2>/dev/null) 2>/dev/null || true
fi

# Sistema de completado moderno
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Modo de teclas Emacs (estándar)
bindkey -e

# Navegación palabra por palabra con Ctrl + Flechas
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

# Borrado rápido de palabras
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word

# Teclas de inicio / fin / suprimir estándar
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

# Pegar desde el portapapeles de Wayland con Ctrl + V
paste-from-clipboard() {
  if command -v wl-paste >/dev/null 2>&1; then
    LBUFFER+="$(wl-paste --no-newline 2>/dev/null)"
  fi
}
zle -N paste-from-clipboard
bindkey '^V' paste-from-clipboard

# Plugin de selección con Shift (Shift + Flechas y Ctrl + Shift + Flechas)
if [[ -f ~/.local/share/zsh/plugins/zsh-shift-select/zsh-shift-select.plugin.zsh ]]; then
  source ~/.local/share/zsh/plugins/zsh-shift-select/zsh-shift-select.plugin.zsh
fi

# Sugerencias automáticas tipo Fish
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Resaltado de sintaxis en tiempo real (siempre al final)
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
export PATH="$HOME/.opencode/bin:$PATH"
