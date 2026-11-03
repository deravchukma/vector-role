# vector-role

Ansible-роль для установки [Vector](https://vector.dev) (сборщик и транспорт логов) из официального архива `tar.gz`:
бинарник в `/opt`, системный пользователь `vector`, systemd-юнит из дистрибутива, конфигурация из переменной.

## Требования

- ansible-core >= 2.14 (модуль `ansible.builtin.systemd_service`);
- целевой хост: Ubuntu 24.04 (noble), x86_64, systemd;
- доступ с хоста к `packages.timber.io`;
- права `become` (sudo).

## Переменные роли

### defaults/main.yml - можно переопределять

| Переменная | По умолчанию | Описание |
|---|---|---|
| `vector_version` | `"0.60.0"` | версия Vector ([релизы](https://vector.dev/releases/)) |
| `vector_install_dir` | `"/opt/vector-{{ vector_version }}"` | каталог распаковки дистрибутива |
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

1. Скачивает архив Vector в домашний каталог пользователя подключения.
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
  version: "1.0.0"
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

## Проверка роли

```bash
ansible-lint
ANSIBLE_ROLES_PATH=.ansible/roles ansible-playbook -i <inventory> tests/test.yml --limit <host>
```

`ansible-lint` создаёт симлинк `.ansible/roles/deravchukma.vector` на каталог роли, его использует `tests/test.yml`.

## Лицензия

MIT

## Автор

Mikhail Deravchuk
