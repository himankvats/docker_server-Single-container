# Building Stage
FROM openjdk:8-alpine as Builder

WORKDIR /app/

RUN set -xe \
  && apk add --no-cache subversion ca-certificates openssl \
  && update-ca-certificates \
  && wget https://cs.gmu.edu/~eclab/projects/ecj/ecj.24.tar.gz \
  && tar oxzvf ecj.24.tar.gz \
  && rm ecj.24.tar.gz \
  && svn checkout https://svn.code.sf.net/p/evotutoring/code/branches/EvoParsons-Epplets/evoparsons evoparsons \
  && svn checkout https://svn.code.sf.net/p/evotutoring/code/branches/EvoParsons-Epplets/org org \
  && svn checkout https://svn.code.sf.net/p/evotutoring/code/branches/EvoParsons-Epplets/testing testing \
  && cd .. \
  && cp -r /app/ecj/ec/ /app/ \
  && mv /app/evoparsons/ecj/parsons /app/ec/ \
  && mv /app/evoparsons/ecj/server /app/ec/

# Environment Variable, which can be override during the runtime.
ENV BROKER_HOSTNAME   TESTNAME
ENV BROKER_PORT       99999
ENV DATA_LOCATION     /data/

RUN set -xe \
  && sed -i 's/int portNum = .*/int portNum = '"$BROKER_PORT;"'/' ec/parsons/BrokerCommunicator.java \
  && sed -i 's/port=.*/port='"$BROKER_PORT"'/' evoparsons/broker/config.property.broker \
  && sed -i 's/hostname=.*/hostname='"$BROKER_HOSTNAME"'/' evoparsons/broker/config.property.broker \
  && sed -i 's#^stat.file.*$#stat.file         = ./DATA.out/evoParsons.stat#g' evoparsons/ecj/params/evoParsons.params \
  && sed -i 's#^stat.child.0.file.*$#stat.child.0.file = ./DATA.out/customEvoParsons.stat#g' evoparsons/ecj/params/evoParsons.params \
  && sed -i 's#^checkpoint-directory = .*$#checkpoint-directory = ./DATA.out#g' evoparsons/ecj/params/evoParsons.params

RUN set -xe \
  && rm -f *.jar \
  && javac -cp ./ ./evoparsons/*/*.java ./ec/parsons/*.java ./ec/server/*.java ./org/problets/lib/comm/rmi/*.java -target 1.6 -source 1.6 \
  && jar cfm ./Broker.jar ./evoparsons/broker/manifest.mf ./evoparsons/*/*.class ./org/problets/lib/comm/rmi/*.class \
  && jar cfm ./ECJ.jar ./ec/parsons/manifest.mf ./ec/server/*.class ./ec/parsons/*.class  ./ec/*.class ./ec/*/*.class ./ec/*/*/*.class ./org/problets/lib/comm/rmi/*.class


# Runtime Stage
FROM openjdk:8-jre-alpine

# We use supervisord to run multiple programs in a single container.
RUN apk add --no-cache supervisor
COPY ./supervisord.conf /etc/



WORKDIR /app/

# Get what we build during the building process
COPY --from=Builder /app/*.jar /app/
COPY --from=Builder /app/evoparsons/psi/Transforms /app/Transforms
COPY --from=Builder /app/evoparsons/psi/Programs /app/Programs
COPY --from=Builder /app/testing/my-config-local-machine.params /app/
COPY --from=Builder /app/testing/simple.params /app/
COPY --from=Builder /app/evoparsons/broker/config.property.broker /app/
COPY --from=Builder /app/evoparsons/ecj/params/evoParsons.params /app/
COPY --from=Builder /app/org/problets/lib/comm/rmi/config.property.relay /app/
COPY --from=Builder /app/testing/simple.params /app/

#For checking codes used for JAR files. Can remove them during production stage. 
COPY --from=Builder /app/ /app/Codes



# Specify where we are going to store the data
VOLUME [ "/data" ]

CMD [ "/usr/bin/supervisord"]
