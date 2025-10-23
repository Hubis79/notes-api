FROM php:8.3-apache

# Install required extensions
RUN docker-php-ext-install pdo pdo_mysql

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Set working dir
WORKDIR /var/www/html

# Copy only composer files for better caching (optional)
# COPY composer.json composer.lock ./
# RUN php -v

# Set DocumentRoot to public
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}/!g' /etc/apache2/apache2.conf

# Allow .htaccess overrides for Laravel public dir
RUN printf '%s\n' "<Directory ${APACHE_DOCUMENT_ROOT}>" \
    "    AllowOverride All" \
    "    Require all granted" \
    "</Directory>" \
    > /etc/apache2/conf-available/override.conf \
    && a2enconf override

# Copy source at runtime via volume in docker-compose
