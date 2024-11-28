Yunus' Traffic Statter 2.0 is a cool tool for checking out what's happening on your network. It uses tshark to grab and look at network packets as they fly by, giving you a real-time peek into your network's activity. You can pick which network interface to watch, and it'll spit out detailed reports and graphs to help you make sense of all that network chatter.
 
Tested for MacOS Silicon! The script relies on Unix-based system utilities and may not function correctly on Windows without modifications. The script is written in Bash and requires a Bash-compatible shell to execute.

Requires: 
macOS: brew install wireshark brew install gnuplot

Debian/Ubuntu: sudo apt-get install tshark sudo apt-get install gnuplot

Fedora: sudo dnf install wireshark-cli sudo dnf install gnuplot

Arch Linux: sudo pacman -S wireshark-cli sudo pacman -S gnuplot

The script uses common command-line tools:
awk
sort
uniq
grep
sed
mkdir
rm
These are typically pre-installed on Unix-based systems.


-Yun
