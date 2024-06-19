# 构建镜像
Mongo v6.0.15

| 镜像名                    | Status        |
| ------------------------ |:-------------:|
| jiangjiali/mongo v6.0.15 | ![CI (Linux)](https://github.com/jiangjiali/docker-mongo/workflows/DockerImageCI/badge.svg) |

## 添加权限
git update-index --chmod=+x docker-entrypoint.sh

## 添加环境变量
* secrets.DOCKER_HUB_USER
* secrets.DOCKER_HUB_PWD