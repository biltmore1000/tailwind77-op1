#!/usr/bin/bash

export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1

if [ ! -f "/system/fonts/NanumGothic.ttf" ]; then
  echo "Installing fonts..."
  mount -o rw,remount /system
  cp -rf /data/openpilot/selfdrive/fonts/kor/NanumGothic* /system/fonts/
  cp -rf /data/openpilot/selfdrive/fonts/kor/fonts/fonts.xml /system/etc/fonts.xml
  chmod 644 /system/etc/fonts.xml
  chmod 644 /system/fonts/NanumGothic*
  cp /data/openpilot/installer/bootanimation.zip /system/media/
  mount -o ro,remount /system
fi

if [ "$(getprop persist.sys.locale)" != "ko-KR" ]; then
  setprop persist.sys.locale ko-KR
  setprop persist.sys.language ko
  setprop persist.sys.country KR
  setprop persist.sys.timezone Asia/Seoul
fi

if [ -z "$BASEDIR" ]; then
  BASEDIR="/data/openpilot"
fi

if [ -z "$PASSIVE" ]; then
  export PASSIVE="1"
fi

STAGING_ROOT="/data/safe_staging"

function launch {
  # Wifi scan
  wpa_cli IFNAME=wlan0 SCAN

  # Check to see if there's a valid overlay-based update available. Conditions
  # are as follows:
  #
  # 1. The BASEDIR init file has to exist, with a newer modtime than anything in
  #    the BASEDIR Git repo. This checks for local development work or the user
  #    switching branches/forks, which should not be overwritten.
  # 2. The FINALIZED consistent file has to exist, indicating there's an update
  #    that completed successfully and synced to disk.

  if [ -f "${BASEDIR}/.overlay_init" ]; then
    find ${BASEDIR}/.git -newer ${BASEDIR}/.overlay_init | grep -q '.' 2> /dev/null
    if [ $? -eq 0 ]; then
      echo "${BASEDIR} has been modified, skipping overlay update installation"
    else
      if [ -f "${STAGING_ROOT}/finalized/.overlay_consistent" ]; then
        if [ ! -d /data/safe_staging/old_openpilot ]; then
          echo "Valid overlay update found, installing"
          LAUNCHER_LOCATION="${BASH_SOURCE[0]}"

          mv $BASEDIR /data/safe_staging/old_openpilot
          mv "${STAGING_ROOT}/finalized" $BASEDIR

          # The mv changed our working directory to /data/safe_staging/old_openpilot
          cd "${BASEDIR}"

          echo "Restarting launch script ${LAUNCHER_LOCATION}"
          exec "${LAUNCHER_LOCATION}"
        else
          echo "openpilot backup found, not updating"
          # TODO: restore backup? This means the updater didn't start after swapping
        fi
      fi
    fi
  fi



  # no cpu rationing for now
  echo 0-3 > /dev/cpuset/background/cpus
  echo 0-3 > /dev/cpuset/system-background/cpus
  echo 0-3 > /dev/cpuset/foreground/boost/cpus
  echo 0-3 > /dev/cpuset/foreground/cpus
  echo 0-3 > /dev/cpuset/android/cpus

  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

  # Remove old NEOS update file
  # TODO: move this code to the updater
  if [ -d /data/neoupdate ]; then
    rm -rf /data/neoupdate
  fi

  #BARGHE Token add files
  if [ ! -f "/data/params/d/AccessToken" ]; then
    echo "Installing AccessToken Key"
    cp -rf /data/openpilot/common/AccessToken /data/params/d
    cp -rf /data/openpilot/common/Dongleld /data/params/d
    chmod 666 /data/params/d/AccessToken
    chmod 666 /data/params/d/Dongleld
  fi

  # Check for NEOS update
  if [ $(< /VERSION) != "14" ]; then
    if [ -f "$DIR/scripts/continue.sh" ]; then
      cp "$DIR/scripts/continue.sh" "/data/data/com.termux/files/continue.sh"
    fi

    "$DIR/installer/updater/updater" "file://$DIR/installer/updater/update.json"
  fi


  # handle pythonpath
  ln -sfn $(pwd) /data/pythonpath
  export PYTHONPATH="$PWD"

  # start manager
  cd selfdrive
  ./manager.py

  # if broken, keep on screen error
  while true; do sleep 1; done
}

launch
