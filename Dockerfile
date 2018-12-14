FROM perl:latest
MAINTAINER James Hunt <james@vaultofcardboard.com>

RUN curl -L http://cpanmin.us | perl - App::cpanminus \
 && cpanm Dancer2 \
          Dancer2::Plugin::DBIC \
          DBIx::Class::Schema::Loader \
          Data::UUID \
          Digest::Bcrypt \
          Data::Entropy::Algorithms

RUN apt-get update \
 && apt-get install -y sqlite3 \
 && rm -rf /var/lib/apt/lists/*

# FIXME: collapse
RUN cpanm LWP::UserAgent
RUN cpanm LWP::Protocol::https

COPY public    /app/public
COPY lib       /app/lib
COPY db        /app/db
COPY bin/start /app/start

EXPOSE 80

CMD ["/app/start"]
