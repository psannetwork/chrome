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


$max ∑_{i∈I} w_i ⋅ x_i$

$∑_{i∈I} r_i ⋅ x_i ≤ T$

$min -∑_{i∈I} w_i ⋅ x_i + P ⋅ (∑_{i∈I} r_i ⋅ x_i - T)^2$

$max ∑_{j∈J} f_j ⋅ x_j$

$∑_{j∈J} c_j ⋅ x_j ≤ B$

$min -∑_{j∈J} f_j ⋅ x_j + P ⋅ (∑_{j∈J} c_j ⋅ x_j - B)^2$


$minimize−i=1∑2​j∈{S,L}∑​wij​xij​+Pi=1∑2​​j∈{S,L}∑​cij​xij​−Ci​​2$



# Chromium

/mnt/host/source/src/third_party/chromiumos-overlay/media-libs/mesa/mesa-21.3.9_p20230109-r9.ebuild

src\third_party\wpa_supplicant\wpa_supplicant

```
# ebuild ファイルを編集
nano /mnt/host/source/src/third_party/chromiumos-overlay/media-libs/mesa/mesa-21.3.9_p20230109-r9.ebuild

# src_configure 関数内に以下の行を追加
src_configure() {
    # 既存のコード...

    # ARM64 向けの EGL プラットフォームを追加
    if use egl; then
        # Staryu (ARM64) 用に drm と surfaceless を追加
        egl_platforms="drm,surfaceless"
    fi

    # 既存のコード...
}
# 修正後
emesonargs+=(
    ...
    -Degl-platforms=drm,surfaceless  # ARM64 向けプラットフォームを追加
    -Ddri-drivers=$(driver_list "${DRI_DRIVERS[*]}")
    -Dgallium-drivers=$(driver_list "${GALLIUM_DRIVERS[*]}")
    -Dvulkan-drivers=$(driver_list "${VULKAN_DRIVERS[*]}")
    ...
)

cros_sdk

# libdrm, libgbm, libx11-xcb をインストール
sudo emerge --ask x11-libs/libdrm media-libs/mesa x11-libs/libX11
# 必要なツールをインストール
sudo emerge --ask sys-devel/bison sys-devel/flex dev-libs/expat

# 全体ビルドを再開
cros build-packages --board=staryu

# Staryu 向けの開発用イメージをビルド
cros build-image --board=staryu dev
```
