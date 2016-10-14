FROM node:5.6.0

MAINTAINER Manish Ranjan manish@moz.com

RUN apt-get update && \
  apt-get install -y wget git build-essential && \
  ln -s /usr/bin/nodejs /usr/bin/node && \
  mkdir -p /deploy/narrows-tracing/node_modules


WORKDIR /deploy/narrows-tracing

# Cache node_modules and source images separately
COPY . /deploy/narrows-tracing/

# npm-install
RUN npm install

# Now building the package
RUN npm run build

#copy all the node modules to container
COPY ./node_modules /deploy/narrows-tracing/node_modules

#copying package.json to container
COPY package.json /deploy/narrows-tracing/

#copy fonts
RUN npm run copy:fonts

# server port on which teh service is exposed
EXPOSE 7880

# start the server
CMD ["npm", "start"]
