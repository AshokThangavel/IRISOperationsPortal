ARG IMAGE=intersystemsdc/irishealth-community
FROM $IMAGE as builder

WORKDIR /home/irisowner/dev


COPY ./ ./

#COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} . ./

USER root
ENV IRISUSERNAME "_SYSTEM" \
    IRISPASSWORD "SYS" \
    PYTHON_PATH=/usr/bin/python3 \
    PATH "/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"


USER ${ISC_PACKAGE_MGRUSER}
RUN iris start IRIS  \
    && iris session IRIS < iris.script | tee /home/irisowner/dev/build.log \
    && iris stop IRIS quietly