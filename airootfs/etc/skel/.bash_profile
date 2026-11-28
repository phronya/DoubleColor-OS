# ~/.bash_profile — DoubleColor OS
# Bash читает этот файл вместо ~/.profile, поэтому подключаем оба.

[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
