FROM ubuntu:jammy

# 允许构建时覆盖（例如，使用MongoDB Enterprise版本构建映像）
# MONGO_PACKAGE选项：mongodb.org或mongodb-enterprise
# MONGO_REPO选项：repo.mongodb.org或repo.mongodb.com
# 例如: docker build --build-arg MONGO_PACKAGE=mongodb-enterprise --build-arg MONGO_REPO=repo.mongodb.com .
ARG MONGO_PACKAGE=mongodb-org
ARG MONGO_REPO=repo.mongodb.org
ENV GOSU_VERSION=1.17 \
	JSYAML_VERSION=3.13.1 \
	MONGO_MAJOR=6.0 \
	MONGO_VERSION=6.0.15 \
	MONGO_PACKAGE=${MONGO_PACKAGE} \
	MONGO_REPO=${MONGO_REPO} \
	HOME=/data/db \
	CONFIGDB=/data/configdb \
	PORTS=27017

RUN set -eux; \
# 首先添加我们的用户和组，以确保它们的id得到一致的分配，而不管添加了什么依赖项
	groupadd --gid 999 --system mongodb; \
	useradd --uid 999 --system --gid mongodb --home-dir $HOME mongodb; \
	mkdir -p $HOME $CONFIGDB; \
	chown -R mongodb:mongodb $HOME $CONFIGDB; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		jq \
		numactl \
		procps \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
# 更新系统安装常用工具
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gnupg \
		wget \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
# 下载/安装 gosu
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
# 下载/安装 js-yaml
	mkdir -p /opt/js-yaml/; \
	wget -O /opt/js-yaml/js-yaml.js "https://github.com/nodeca/js-yaml/raw/${JSYAML_VERSION}/dist/js-yaml.js"; \
	wget -O /opt/js-yaml/package.json "https://github.com/nodeca/js-yaml/raw/${JSYAML_VERSION}/package.json"; \
	ln -s /opt/js-yaml/js-yaml.js /js-yaml.js; \
	\
# 下载/安装 MongoDB PGP keys
	export GNUPGHOME="$(mktemp -d)"; \
	wget -O KEYS 'https://pgp.mongodb.com/server-6.0.asc'; \
	gpg --batch --import KEYS; \
	mkdir -p /etc/apt/keyrings; \
	gpg --batch --export --armor '39BD841E4BE5FB195A65400E6A26B1AE64C3C388' > /etc/apt/keyrings/mongodb.asc; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" KEYS; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# 烟雾测试
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true; \
# 创建初始化数据文件夹
	mkdir /docker-entrypoint-initdb.d; \
# 源地址
	echo "deb [ signed-by=/etc/apt/keyrings/mongodb.asc ] http://$MONGO_REPO/apt/ubuntu jammy/${MONGO_PACKAGE%-unstable}/$MONGO_MAJOR multiverse" | tee "/etc/apt/sources.list.d/${MONGO_PACKAGE%-unstable}.list"; \
# 安装 mongodbenterprise 会引入提示输入的 tzdata
	export DEBIAN_FRONTEND=noninteractive; \
	apt-get update; \
	apt-get install -y \
		${MONGO_PACKAGE}=$MONGO_VERSION \
		${MONGO_PACKAGE}-server=$MONGO_VERSION \
		${MONGO_PACKAGE}-shell=$MONGO_VERSION \
		${MONGO_PACKAGE}-mongos=$MONGO_VERSION \
		${MONGO_PACKAGE}-tools=$MONGO_VERSION \
		${MONGO_PACKAGE}-database=$MONGO_VERSION \
		${MONGO_PACKAGE}-database-tools-extra=$MONGO_VERSION; \
	rm -rf /var/lib/apt/lists/*; \
	rm -rf /var/lib/mongodb; \
	mv /etc/mongod.conf /etc/mongod.conf.orig

VOLUME $HOME $CONFIGDB

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE $PORTS
CMD ["mongod"]
