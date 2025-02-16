ARG NODE_VERSION=18.20.6

FROM node:${NODE_VERSION}-alpine AS node
FROM olivergra/php:latest

COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

ENV FOP_HOME=/usr/share/fop-2.1 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    LD_PRELOAD=/usr/lib/preloadable_libiconv.so

RUN set -xe \
    && apk add --no-cache --virtual .phpext-builddeps \
      gettext-dev \
      libxslt-dev \
      zlib-dev \
      libmemcached-dev \
      libzip-dev \
      oniguruma-dev \
      autoconf \
      build-base \
      openldap-dev \
    && docker-php-ext-install \
      calendar \
      gettext \
      mbstring \
      mysqli \
      opcache \
      pcntl \
      pdo_mysql \
      sockets \
      xsl \
      zip \
      ldap \
    && pecl install apcu pcov \
    && curl -Ls https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.tar.gz | tar xz -C / \
    && cd /pecl-memcache-NON_BLOCKING_IO_php7 \
    && phpize && ./configure && make && make install \
    && cd / && rm -rf /pecl-memcache-NON_BLOCKING_IO_php7 \
    && docker-php-ext-enable apcu memcache pcov \
    && apk add --no-cache --virtual .phpext-rundeps \
      gettext \
      libxslt \
      libmemcached-libs \
      libzip \
      openldap-dev \
    && apk del .phpext-builddeps \
    && pecl clear-cache \
    && apk add --no-cache --virtual .atom-deps \
      openjdk8-jre-base \
      ffmpeg \
      imagemagick \
      ghostscript \
      poppler-utils \
      make \
      bash \
      gnu-libiconv \
      fcgi \
    && npm install -g "less@<4.0.0" \
    && curl -Ls https://downloads.apache.org/xmlgraphics/fop/binaries/fop-2.10-bin.tar.gz | tar xz -C /usr/share \
    && ln -sf /usr/share/fop-2.10/fop /usr/local/bin/fop \
    && echo "extension=ldap.so" > /usr/local/etc/php/conf.d/docker-php-ext-ldap.ini

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.* /atom/build/

RUN --mount=type=secret,id=api_token,env=API_TOKEN \
    composer config -g github-oauth.github.com ${API_TOKEN} \
    && composer install -d /atom/build

COPY package* /atom/build/

RUN set -xe && npm ci --prefix /atom/build

COPY . /atom/src

WORKDIR /atom/src

RUN set -xe \
    && mv /atom/build/vendor/composer vendor/ \
    && mv /atom/build/node_modules . \
    && make -C plugins/arDominionPlugin \
    && make -C plugins/arArchivesCanadaPlugin \
    && npm run build \
    && rm -rf /atom/build

# RUN set -xe && npm prune --production

ENTRYPOINT ["docker/entrypoint.sh"]

CMD ["fpm"]
