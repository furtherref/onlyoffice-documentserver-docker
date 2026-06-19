#!/usr/bin/env bash
set -euo pipefail

required_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "::error::Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

required_env PRODUCT_VERSION
required_env BUILD_NUMBER
required_env BUILD_PLATFORM
required_env PACKAGE_UNAME_M
required_env DEB_ARCH

WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
BUILD_TOOLS_DIR="${WORKSPACE_DIR}/build_tools"
DOCUMENTSERVER_DIR="${WORKSPACE_DIR}/onlyoffice-documentserver"
PACKAGE_DIR="${WORKSPACE_DIR}/document-server-package"
ARTIFACT_DIR="${WORKSPACE_DIR}/artifacts"
QT_TARGET="${QT_TARGET:-${DEB_ARCH}}"

if [ ! -d "${BUILD_TOOLS_DIR}" ]; then
  echo "::error::build_tools checkout is missing at ${BUILD_TOOLS_DIR}" >&2
  exit 1
fi
if [ ! -d "${DOCUMENTSERVER_DIR}" ]; then
  echo "::error::DocumentServer checkout is missing at ${DOCUMENTSERVER_DIR}" >&2
  exit 1
fi
if [ ! -d "${PACKAGE_DIR}" ]; then
  echo "::error::document-server-package checkout is missing at ${PACKAGE_DIR}" >&2
  exit 1
fi

cd "${WORKSPACE_DIR}"

ln -sfn onlyoffice-documentserver/core core
ln -sfn onlyoffice-documentserver/core-fonts core-fonts
ln -sfn onlyoffice-documentserver/dictionaries dictionaries
ln -sfn onlyoffice-documentserver/sdkjs sdkjs
ln -sfn onlyoffice-documentserver/server server
ln -sfn onlyoffice-documentserver/web-apps web-apps
ln -sfn onlyoffice-documentserver/document-formats document-formats
ln -sfn onlyoffice-documentserver/document-templates document-templates
ln -sfn onlyoffice.github.io onlyoffice.github.io

sudo apt-get update
sudo apt-get install -y \
  binutils \
  binutils-aarch64-linux-gnu \
  binutils-x86-64-linux-gnu \
  debhelper \
  devscripts \
  fakeroot \
  git-lfs \
  jq \
  m4 \
  python-is-python3 \
  xz-utils

git lfs install --local || true

cd "${BUILD_TOOLS_DIR}/tools/linux"
if [ "${DEB_ARCH}" = "arm64" ]; then
  rm -rf ./python3
  mkdir -p ./python3/bin
  ln -s "$(command -v python3)" ./python3/bin/python3
  ln -s python3 ./python3/bin/python
elif [ ! -x ./python3/bin/python3 ]; then
  ./python.sh
fi

case "${QT_TARGET}" in
  amd64) QT_COMPILER="gcc_64" ;;
  arm64) QT_COMPILER="gcc_arm64" ;;
  *) echo "::error::Unsupported QT_TARGET: ${QT_TARGET}" >&2; exit 1 ;;
esac

if [ ! -x "./qt_build/Qt-5.9.9/${QT_COMPILER}/bin/qmake" ]; then
  ./python3/bin/python3 ./qt_binary_fetch.py "${QT_TARGET}"
fi

rm -f ./packages_complete
export npm_config_force=true
export NPM_CONFIG_FORCE=true
./python3/bin/python3 ./deps.py
unset npm_config_force
unset NPM_CONFIG_FORCE
sudo ./cmake.sh

cd "${BUILD_TOOLS_DIR}/tools/linux/sysroot"
./../python3/bin/python3 ./fetch.py all

cd "${BUILD_TOOLS_DIR}"
./tools/linux/python3/bin/python3 ./configure.py \
  --update "0" \
  --branch "${SOURCE_REF:-${PRODUCT_VERSION}-${BUILD_NUMBER}}" \
  --clean "1" \
  --module "server" \
  --platform "${BUILD_PLATFORM}" \
  --qt-dir "${BUILD_TOOLS_DIR}/tools/linux/qt_build/Qt-5.9.9" \
  --sysroot "1" \
  --sdkjs-addon " "

./tools/linux/python3/bin/python3 ./make.py

cd "${PACKAGE_DIR}"
make clean
make deb \
  -e PRODUCT_NAME=documentserver \
  -e PRODUCT_VERSION="${PRODUCT_VERSION}" \
  -e BUILD_NUMBER="${BUILD_NUMBER}" \
  -e UNAME_M="${PACKAGE_UNAME_M}"

mkdir -p "${ARTIFACT_DIR}"
DEB_FILE="deb/onlyoffice-documentserver_${PRODUCT_VERSION}-${BUILD_NUMBER}_${DEB_ARCH}.deb"
if [ ! -f "${DEB_FILE}" ]; then
  echo "::error::Expected package was not created: ${PACKAGE_DIR}/${DEB_FILE}" >&2
  find deb -maxdepth 1 -type f -print >&2
  exit 1
fi

cp "${DEB_FILE}" "${ARTIFACT_DIR}/"
ls -lh "${ARTIFACT_DIR}"
