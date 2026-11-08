#!/bin/bash
# Подготовка cgroup v2 для podman внутри контейнера (docker run --privileged ... aragast/netology).
# Корневая группа контейнера с процессами не может раздавать контроллеры дочерним группам,
# поэтому переносим процессы в дочернюю группу init и включаем контроллеры.
# На хосте с cgroup v1 ничего не делает.
set -eu
[ -f /sys/fs/cgroup/cgroup.controllers ] || exit 0
mkdir -p /sys/fs/cgroup/init
xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || :
sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers > /sys/fs/cgroup/cgroup.subtree_control
