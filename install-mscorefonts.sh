#!/usr/bin/env bash
set -euo pipefail

font_dir="/usr/share/fonts/truetype/msttcorefonts"
doc_dir="/usr/share/doc/ttf-mscorefonts-installer"
state_dir="/var/lib/msttcorefonts"
download_dir="$(mktemp -d)"
scratch_dir="$(mktemp -d)"

cleanup() {
  rm -rf "${download_dir}" "${scratch_dir}"
}
trap cleanup EXIT

base_urls=(
  "https://downloads.sourceforge.net/project/corefonts/the%20fonts/final"
  "https://downloads.sourceforge.net/corefonts"
  "https://pilotfiber.dl.sourceforge.net/project/corefonts/the%20fonts/final"
  "https://netix.dl.sourceforge.net/project/corefonts/the%20fonts/final"
)

download_exe() {
  local file="$1"
  local checksum="$2"
  local target="${download_dir}/${file}"
  local base_url
  local attempt

  for base_url in "${base_urls[@]}"; do
    for attempt in 1 2; do
      rm -f "${target}"
      if wget -q --timeout=30 --tries=2 -O "${target}" "${base_url}/${file}" &&
        printf '%s  %s\n' "${checksum}" "${target}" | sha256sum -c --status; then
        return 0
      fi
    done
  done

  echo "Failed to download a verified copy of ${file}" >&2
  return 1
}

while IFS='|' read -r file checksum; do
  [ -z "${file}" ] && continue
  download_exe "${file}" "${checksum}"
done <<'EOF'
andale32.exe|0524fe42951adc3a7eb870e32f0920313c71f170c859b5f770d82b4ee111e970
arial32.exe|85297a4d146e9c87ac6f74822734bdee5f4b2a722d7eaa584b7f2cbf76f478f6
arialb32.exe|a425f0ffb6a1a5ede5b979ed6177f4f4f4fdef6ae7c302a7b7720ef332fec0a8
comic32.exe|9c6df3feefde26d4e41d4a4fe5db2a89f9123a772594d7f59afd062625cd204e
courie32.exe|bb511d861655dde879ae552eb86b134d6fae67cb58502e6ff73ec5d9151f3384
georgi32.exe|2c2c7dcda6606ea5cf08918fb7cd3f3359e9e84338dc690013f20cd42e930301
impact32.exe|6061ef3b7401d9642f5dfdb5f2b376aa14663f6275e60a51207ad4facf2fccfb
times32.exe|db56595ec6ef5d3de5c24994f001f03b2a13e37cee27bc25c58f6f43e8f807ab
trebuc32.exe|5a690d9bb8510be1b8b4fe49f1f2319651fe51bbe54775ddddd8ef0bd07fdac9
verdan32.exe|c1cb61255e363166794e47664e2f21af8e3a26cb6346eb8d2ae2fa85dd5aad96
webdin32.exe|64595b5abc1080fba8610c5c34fab5863408e806aafe84653ca8575bed17d75a
EOF

cd "${scratch_dir}"
for exe in "${download_dir}"/*.exe; do
  cabextract -q "${exe}"
done

for path in ./*; do
  [ -f "${path}" ] || continue
  name="${path#./}"
  lower="$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]')"
  if [ "${name}" != "${lower}" ]; then
    mv -f -- "${name}" "${lower}"
  fi
done

install -d -m 0755 "${font_dir}" "${doc_dir}" "${state_dir}"
if [ -f "${scratch_dir}/licen.txt" ]; then
  install -m 0644 "${scratch_dir}/licen.txt" "${doc_dir}/READ_ME"
fi
: > "${state_dir}/ms-fonts"

while IFS='|' read -r source target checksum; do
  [ -z "${source}" ] && continue
  install -m 0644 "${scratch_dir}/${source}" "${font_dir}/${target}"
  ln -sf "${target}" "${font_dir}/${source}"
  printf '%s  %s\n' "${checksum}" "${font_dir}/${target}" | sha256sum -c --status
  printf '%s\n%s\n' "${target}" "${source}" >> "${state_dir}/ms-fonts"
done <<'EOF'
andalemo.ttf|Andale_Mono.ttf|48d9bc613917709d3b0e0f4a6d4fe33a5c544c5035dffe9e90bc11e50e822071
ariblk.ttf|Arial_Black.ttf|dad7c04acb26e23dfe4780e79375ca193ddaf68409317e81577a30674668830e
arial.ttf|Arial.ttf|35c0f3559d8db569e36c31095b8a60d441643d95f59139de40e23fada819b833
arialbd.ttf|Arial_Bold.ttf|4044aa6b5bebbc36980206b45b0aaaaa5681552a48bcadb41746d5d1d71fd7b4
arialbi.ttf|Arial_Bold_Italic.ttf|2f371cd9d96b3ac544519d85c16dc43ceacdfcea35090ee8ddf3ec5857c50328
ariali.ttf|Arial_Italic.ttf|70ade233175a6a6675e4501461af9326e6f78b1ffdf787ca0da5ab0fc8c9cfd6
comic.ttf|Comic_Sans_MS.ttf|b82c53776058f291382ff7e008d4675839d2dc21eb295c66391f6fb0655d8fc0
comicbd.ttf|Comic_Sans_MS_Bold.ttf|873361465d994994762d0b9845c99fc7baa2a600442ea8db713a7dd19f8b0172
cour.ttf|Courier_New.ttf|6715838c52f813f3821549d3f645db9a768bd6f3a43d8f85a89cb6875a546c61
courbd.ttf|Courier_New_Bold.ttf|edf8a7c5bfcac2e1fe507faab417137cbddc9071637ef4648238d0768c921e02
couri.ttf|Courier_New_Italic.ttf|f3f6b09855b6700977e214aab5eb9e5be6813976a24f894bd7766e92c732fbe1
courbi.ttf|Courier_New_Bold_Italic.ttf|66dbfa20b534fba0e203da140fec7276a45a1069e424b1b9c35547538128bbe8
georgia.ttf|Georgia.ttf|7d0bb20c632bb59e81a0885f573bd2173f71f73204de9058feb68ce032227072
georgiab.ttf|Georgia_Bold.ttf|82d2fbadb88a8632d7f2e8ad50420c9fd2e7d3cbc0e90b04890213a711b34b93
georgiai.ttf|Georgia_Italic.ttf|1523f19bda6acca42c47c50da719a12dd34f85cc2606e6a5af15a7728b377b60
georgiaz.ttf|Georgia_Bold_Italic.ttf|c983e037d8e4e694dd0fb0ba2e625bca317d67a41da2dc81e46a374e53d0ec8a
impact.ttf|Impact.ttf|00f1fc230ac99f9b97ba1a7c214eb5b909a78660cb3826fca7d64c3af5a14848
times.ttf|Times_New_Roman.ttf|4e98adeff8ccc8ef4e3ece8d4547e288ff85fdc9c7ca711a4599c234874bbe86
timesbd.ttf|Times_New_Roman_Bold.ttf|4357b63cef20c01661a53c5dae70ffd20cb4765503aaed6d38b17a57c5a90bff
timesbi.ttf|Times_New_Roman_Bold_Italic.ttf|192e1b0d18e90334e999a99f8c32808d6a2e74b3698b8cd90c943c2249a46549
timesi.ttf|Times_New_Roman_Italic.ttf|c25ae529b4cecdbca148b6ccb862ee0abad770af8b1fd29c8dba619d1b8da78a
trebuc.ttf|Trebuchet_MS.ttf|ec3ffb302488251e1b67fb09dd578b364c5339e27c1cfb26eb627666236453d0
trebucbd.ttf|Trebuchet_MS_Bold.ttf|f65941f9487c0a0a3b7445996ecbbd24466d7ae76ea2a597ced55f438fa63838
trebucit.ttf|Trebuchet_MS_Italic.ttf|db56fdac7d3ba20b7aededcb6ee86c46687489d17b759e1708ea4e2d21e38410
trebucbi.ttf|Trebuchet_MS_Bold_Italic.ttf|c0a6bdf31f9f2953b2f08a0c1734c892bc825f0fb17c604d420f7acf203a213b
verdana.ttf|Verdana.ttf|96ed14949ca4b7392cff235b9c41d55c125382abbe0c0d3c2b9dd66897cae0cb
verdanab.ttf|Verdana_Bold.ttf|c8f5065ba91680f596af3b0378e2c3e713b95a523be3d56ae185ca2b8f5f0b23
verdanai.ttf|Verdana_Italic.ttf|91b59186656f52972531a11433c866fd56e62ec4e61e2621a2dba70c8f19a828
verdanaz.ttf|Verdana_Bold_Italic.ttf|698e220f48f4a40e77af7eb34958c8fd02f1e18c3ba3f365d93bfa2ed4474c80
webdings.ttf|Webdings.ttf|10d099c88521b1b9e380b7690cbe47b54bb19396ca515358cfdc15ac249e2f5d
EOF

font_count="$(find "${font_dir}" -maxdepth 1 -type f -iname '*.ttf' | wc -l)"
if [ "${font_count}" -lt 30 ]; then
  echo "Expected at least 30 Microsoft core fonts, got ${font_count}" >&2
  exit 1
fi

fc-cache -f "${font_dir}"
echo "Installed ${font_count} Microsoft core fonts."
