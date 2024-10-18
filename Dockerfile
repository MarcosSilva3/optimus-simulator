FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

# Update package lists and install updates
RUN apt-get update && apt-get -y install apt-transport-https \
    && sed -e 's/^deb-src/# deb-src/' -i /etc/apt/sources.list \
    && sed -e 's/^# deb /deb /' -i /etc/apt/sources.list \
    && apt-get update && apt-get -y upgrade && apt-get -y autoremove \
    && apt-get -y install apt-utils gcc g++ git make man vim

RUN apt-get install -y \
    curl \
    gcc \
    make \
    libplack-perl \
    libwww-perl \
    libdate-calc-perl \
    libexcel-writer-xlsx-perl \
    libxml-simple-perl \
    liblwp-protocol-https-perl \
    libdbi-perl \
    libdbd-sqlite3-perl \
    libdbd-pg-perl \
    libjson-perl \
    libdancer2-perl \
    cpanminus \
    libxml2-dev \
    libssl-dev
    
RUN cpanm --notest Paws
RUN cpanm --notest Paws::Net::LWPCaller
RUN cpanm --notest JSON::Parse \
    Dancer2::Logger::Console::Colored \
    Dancer2::Plugin::Database \
    Encode \
    Cwd \
    Data::Dumper \
    Plack::Middleware::CrossOrigin \
    Plack::Builder \
    FindBin \
    Amazon::S3::Thin \
    File::Basename \
    File::Copy \
    Statistics::Descriptive \
    DateTime \
    Mojolicious \
    Mojo::File \
    URL::Encode \
    JSON::MaybeXS \
    HTML::TableExtract \
    Try::Tiny::Retry \
    MIME::Base64 \
    Geo::WKT::Simple
    

WORKDIR /hom
COPY . /hom
EXPOSE 3000
WORKDIR /hom
CMD plackup --port 3000 ./bin/app.psgi
