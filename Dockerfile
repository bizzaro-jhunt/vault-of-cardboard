FROM perl:latest
MAINTAINER James Hunt <james@vaultofcardboard.com>

RUN apt-get update \
 && apt-get install -y sqlite3 \
 && rm -rf /var/lib/apt/lists/* \
 && curl -L http://cpanmin.us | perl - App::cpanminus \
 && cpanm Dancer2 \
          Dancer2::Plugin::DBIC \
          DBIx::Class::Schema::Loader \
          Data::UUID \
          Digest::Bcrypt \
          Data::Entropy::Algorithms \
          LWP::UserAgent \
          LWP::Protocol::https \
          Net::Amazon::S3 \
          Text::CSV

RUN cpanm Data::Entropy::Algorithms \
          JSON::PP

COPY public    /app/public
COPY lib       /app/lib
COPY db        /app/db
COPY bin/start /app/start
COPY bin/vcb   /bin/vcb

EXPOSE 80

CMD ["/app/start"]
