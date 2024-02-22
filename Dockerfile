FROM stesie/libv8-10.5 AS builder
MAINTAINER Stefan Siegl <stesie@brokenpipe.de>

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    php-dev git ca-certificates g++ make

RUN git clone --branch php7 https://github.com/phpv8/v8js.git /usr/local/src/v8js
WORKDIR /usr/local/src/v8js

RUN phpize
RUN ./configure --with-v8js=/opt/libv8-10.5 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS -DV8_ENABLE_SANDBOX"
RUN make all -j`nproc`

FROM phpswoole/swoole:5.0.2-php8.2

ENV PROJECT_ROOT="/app"
WORKDIR ${PROJECT_ROOT}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
     curl \
     iproute2 \
     gnupg2 \
     libxml2-dev \
     libzip-dev \
     libonig-dev \
     zlib1g-dev \
     libpng-dev \
     netcat \
     git \
     libnode-dev \
     unzip; \
    pecl install redis && echo "extension=redis.so" > /usr/local/etc/php/conf.d/ext-redis.ini ; \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -; \
    apt-get install -y --no-install-recommends nodejs;

COPY --from=builder "/usr/lib/x86_64-linux-gnu/libstdc++.so.*" /usr/lib/x86_64-linux-gnu/
COPY --from=builder /opt/libv8-10.5 /opt/libv8-10.5/
RUN apt-get -y install patchelf \
    && for A in /opt/libv8-10.5/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A; done

COPY --from=builder /usr/local/src/v8js/modules/v8js.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/

RUN docker-php-ext-enable v8js

RUN docker-php-ext-install mysqli pdo pdo_mysql sockets mbstring zip opcache gd pcntl

RUN echo "memory_limit=2048M" > ${PHP_INI_DIR}/conf.d/memory-limit.ini
RUN echo "upload_max_filesize=32M" >> ${PHP_INI_DIR}/conf.d/upload-limit.ini
RUN echo "post_max_size=32M" >> ${PHP_INI_DIR}/conf.d/post-limit.ini
RUN echo "default_socket_timeout=600" >> ${PHP_INI_DIR}/conf.d/socket-timeout.ini
RUN echo "max_execution_time=600" >> ${PHP_INI_DIR}/conf.d/max-timeout.ini
RUN echo "max_input_time=600" >> ${PHP_INI_DIR}/conf.d/max-input-timeout.ini

# clean up
RUN docker-php-source delete ; \
    apt-get -y purge ; \
    apt-get -y clean 2>/dev/null && apt-get -y autoremove 2>/dev/null ; \
    rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*;

COPY . ${PROJECT_ROOT}

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod 775 /entrypoint.sh

RUN chmod -R 777 /app/bootstrap /app/storage

ENTRYPOINT ["/entrypoint.sh"]
