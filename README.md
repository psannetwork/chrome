言語を日本語にするには
/scripts/initial-setup.sh

あと、
sudo apt install fcitx-mozc
sudo apt install fcitx-m17n
dbusからfcitxにする

設定からjapanese - Mozc

アプリは
wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash
これね　ラズパイのやつ


# crouton

steam

https://wiki.postmarketos.org/wiki/Steam_in_box86

audio

```
sudo apt-get remove --purge pulseaudio alsa-base -y

sudo apt-get install alsa-base -y


sudo apt install --reinstall alsa-base alsa-utils

sudo alsa force-reload

sudo modprobe snd_soc_mt8186
sudo modprobe snd_sof

```
