# vector-role

Ansible-роль для установки [Vector](https://vector.dev) (сборщик и транспорт логов) из официального архива `tar.gz`:
бинарник в `/opt`, системный пользователь `vector`, systemd-юнит из дистрибутива, конфигурация из переменной.

## Требования

- ansible-core >= 2.14 (модуль `ansible.builtin.systemd_service`);
- целевой хост: Ubuntu 24.04 (noble) / 26.04 (resolute) или Oracle Linux 8, x86_64, systemd;
- доступ с хоста к `packages.timber.io`;
- права `become` (sudo).

## Переменные роли

### defaults/main.yml - можно переопределять

| Переменная | По умолчанию | Описание |
|---|---|---|
| `vector_version` | `"0.60.0"` | версия Vector ([релизы](https://vector.dev/releases/)) |
| `vector_install_dir` | `"/opt/vector-{{ vector_version }}"` | каталог распаковки дистрибутива |
| `vector_download_dir` | `"/tmp"` | каталог для скачанного архива (абсолютный путь) |
| `vector_config` | демо-пайплайн | содержимое `vector.yaml` в виде словаря: `demo_logs` -> `remap` (разбор syslog) -> `console` (JSON в journald) |

### vars/main.yml - внутренние, не переопределять

| Переменная | Значение | Описание |
|---|---|---|
| `vector_config_dir` | `/etc/vector` | каталог конфигурации: юнит запускает `vector` без `--config`, путь по умолчанию |
| `vector_data_dir` | `/var/lib/vector` | каталог данных Vector по умолчанию |
| `vector_arch` | `x86_64-unknown-linux-gnu` | архитектура дистрибутива |
| `vector_archive` | `vector-{{ vector_version }}-{{ vector_arch }}.tar.gz` | имя архива |
| `vector_url` | `https://packages.timber.io/vector/...` | адрес скачивания архива |

## Что делает роль

1. Скачивает архив Vector в `vector_download_dir`.
2. Распаковывает его в `vector_install_dir` (повторно не распаковывает) и делает симлинк `/usr/bin/vector`.
3. Создаёт системные группу и пользователя `vector` и каталоги конфигурации и данных.
4. Генерирует `/etc/vector/vector.yaml` из `vector_config`. Перед заменой файл проверяется командой `vector validate`:
   ошибка в конфигурации не ломает работающий сервис.
5. Устанавливает systemd-юнит из дистрибутива, включает и запускает сервис.
   При изменении бинарника, конфигурации или юнита сервис перезапускается (handler `Restart vector service`).

## Теги

| Тег | Задачи |
|---|---|
| `download` | скачивание архива |
| `install` | распаковка, симлинк, пользователь, каталог данных, юнит |
| `config` | каталог и файл конфигурации |

Запуск сервиса выполняется при любом наборе тегов.

## Зависимости

Нет.

## Установка

`requirements.yml`:

```yaml
---
- src: git@github.com:deravchukma/vector-role.git
  scm: git
  version: "1.1.1"
  name: vector
```

```bash
ansible-galaxy install -r requirements.yml -p roles
```

## Пример playbook

С конфигурацией по умолчанию (демо-пайплайн):

```yaml
---
- name: Install Vector
  hosts: vector
  roles:
    - vector
```

Со своей конфигурацией: логи journald в файл:

```yaml
---
- name: Install Vector
  hosts: vector
  roles:
    - role: vector
      vars:
        vector_config:
          sources:
            journal:
              type: journald
          sinks:
            to_file:
              type: file
              inputs: [journal]
              path: /var/lib/vector/journal-%Y-%m-%d.log
              encoding:
                codec: json
```

## Тестирование

### Molecule

Сценарий `default` (драйвер `docker`) проверяет роль на `oraclelinux:8` и `ubuntu:latest`.
Образы собираются из `molecule/default/Dockerfile.j2` (python3, systemd, sudo), PID 1 в контейнере — systemd.

Требования: molecule 6.0.3, molecule-plugins[docker] 23.5.3, ansible-core 2.16,
коллекции `community.docker` (>= 3.10.2, < 5.0.0) и `ansible.posix`.

```bash
molecule test        # полный сценарий: create, converge, idempotence, verify, destroy
molecule converge    # только создать контейнеры и применить роль
molecule verify      # только проверки
molecule login --host ubuntu_latest
molecule destroy
```

Проверки `verify.yml`: версия Vector совпадает с `vector_version`, `vector validate` проходит по развёрнутому конфигу,
сервис `running` и `enabled`, пользователь `vector` существует, конфиг на хосте совпадает с `vector_config`,
в журнале сервиса появляются обработанные события.

### Tox

`tox.ini` проверяет роль на разных версиях Ansible на управляющей машине: Python 3.9 × ansible-core 2.14 / 2.15.
Каждое окружение запускает облегчённый сценарий molecule `tox` (драйвер `podman`, одна платформа `oraclelinux:8`,
этапы `dependency, destroy, create, converge, verify, destroy`). `converge.yml` и `verify.yml` общие со сценарием `default`.

Запуск в контейнере с podman, tox и Python 3.9:

```bash
docker run --privileged=True -v <путь к роли>:/opt/vector-role -w /opt/vector-role -it aragast/netology:latest /bin/bash
tox
```

Перед тестом tox выполняет `molecule/tox/prepare-cgroups.sh`: на хосте с cgroup v2 без этого podman внутри контейнера
не может создать контейнер. `molecule/tox/Dockerfile.j2` выставляет `/etc/shadow` права `0400`:
с правами `0000` в privileged-контейнере не работает `sudo`.

### ansible-lint

```bash
ansible-lint
```

## Лицензия

MIT

## Автор

Mikhail Deravchuk
