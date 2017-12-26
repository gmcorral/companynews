FROM httpd:alpine

# download & install static files
ADD https://s3.amazonaws.com/infra-assessment/static.zip /tmp/static.zip

# install on Apache
RUN unzip /tmp/static.zip -d /tmp/ \
&&  mkdir /usr/local/apache2/htdocs/companyName \
&&  cp -R /tmp/static/* /usr/local/apache2/htdocs/companyName/ \
&&  rm -Rf /tmp/static /tmp/static.zip
